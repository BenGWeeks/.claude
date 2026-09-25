---
name: gen-video
description: Generate photoreal video clips with Google Veo 3.1 (Gemini API), pinned to a first and last frame so clips loop and stitch seamlessly, with a cost guard. Use for scene loops, background event clips, character entrances and transitions. Includes the hard-won lessons from building Sergeant Sammie's airbase scene (prompting, joins, audio, colour, review and spend).
---

# gen-video

`generate.py` makes one Veo 3.1 clip from a prompt and a first frame, optionally
pinned to a last frame. It prints a cost estimate and **refuses to spend** unless
you pass `--yes` and the estimate is under `--max-gbp` (default £5).

```
python3 ~/.claude/skills/gen-video/generate.py --prompt-file shot.txt \
    --first plate.png --last plate.png --out clips/idle.mp4 --fast          # dry run: prints estimate
python3 ~/.claude/skills/gen-video/generate.py ... --yes                    # generates
```

Key: `GEMINI_API_KEY`, else `~/.config/gemini/api_key` (mode 600). Never printed.
The user provisions it in their own terminal, never in chat.

## Money first (the lesson that cost £200)

- **Estimate and ask before every batch.** An 8 s Veo 3.1 clip with sound costs
  roughly £2.50–£5, so a 10-clip batch is about £25–£50. On 2026-09-24/25 about 60
  clips, many of them retakes, used a whole £200 top-up in hours.
- **Billing is per billing account, not per project or key.** Two projects on one
  prepaid account share one balance. Draining it killed another live service (a
  realtime voice agent) mid-call. Give video work its own billing account or a
  spend cap. The account's "Tier cap" is **not** a spend limit.
- **Draft with `--fast`**, then take the final at standard quality.
- A new project on the free tier has **no Veo quota**: expect 429 until billing is
  linked. 402 means the prepaid credit is exhausted.
- `Spend` in AI Studio shows real money. `Usage` counts status polls, which are free.

## Joins: pin both ends

- Pin **first and last frames** for anything that loops or chains. Clips then start
  and end on the same frame, and any clip can follow any other.
- A pinned last frame **needs `--seconds 8`**. At 4 s, Veo answers 400 "use case
  not supported".
- Make keyframes as **image edits of one plate** (same framing), not frames taken
  from the end of a previous clip. Taking them from a clip inherits its camera drift.
- **Veo lands close to a pinned frame, not on it.** The eyes came out as small points
  instead of discs, and steam differs. Fix it in post:
  - blend a loop's last 8 frames into its first;
  - blend an entrance's last ~12 frames into the frame that follows it.
- Measure every join: mean absolute luma difference on 10×10 blocks at 160×90.
  Under about 1 against normal motion is invisible. Look for the worst block, not
  just the mean.
- A loop can only hand over where it matches its first frame, and moving steam
  makes that rare. For on-demand transitions, **crossfade 12 frames from whatever
  frame is showing** (PIL `Image.blend` over the raw YU12 buffer is about 1 ms).

## Prompting: say everything, Veo fills gaps badly

Things that went wrong, and the sentence that fixed each:

| Problem | Add |
|---|---|
| Two copies of the character | "There is exactly ONE X in this whole clip… never splits, duplicates or merges" |
| Pointing, waving, saluting | "His arms stay straight down at his sides… he never points, gestures, waves or salutes" |
| Crouching or kneeling mid-walk | "He walks upright the whole way and never crouches, bends, kneels or ducks" |
| A crowd walks through the standing rank | Route it away: "…only ever moves to the RIGHT, never to the left… stays far from the rank" |
| Vehicle too big, hides the subject | "the same size as a small fuel truck… never hides the dropship" and name a known route |
| Aircraft fading in mid-sky | "enter from beyond the LEFT edge already fully visible and solid… never fade in or out" |
| A hovering ship drifts off-frame | "moves ONLY straight up and straight down, like a lift… never drifts sideways" |
| The rank crouches in the downwash | "stays upright at attention the whole time: they do not crouch, kneel or bend" |
| An event cut off by a transition | keep the base loop **calm** ("Nothing drives, lands or passes") and put events in variants |
| Static smoke | "A little steam drifts slowly and continuously… from the first frame to the last" (big blooms are OK) |

- Keep camera words in every prompt: "Locked-off static camera… framing never changes".
- Put an overlay's footprint (a character composited later) in mind: anything behind
  it is invisible. Route events to the sides.

## Review: composited, zoomed, before accepting

- Review with the overlay composited, as the viewer sees it:
  `ffmpeg -i clip.mp4 -i overlay.png -filter_complex "[0][1]overlay,select='eq(n\,0)+eq(n\,48)+…',scale=320:180,tile=8x1"`
- Then **zoom** into anything suspicious; contact sheets hide crouches and plumes.
- Retire rejected takes to a `retired/` folder that git ignores and deploys exclude.
  Never delete them before the replacement is accepted.
- Tighten the prompt **before** retaking. A blind retry costs the same and fails the same way.

## Audio

- Veo's own soundtrack is useful only for **events**. Gate it with the floor at the
  **10th-percentile** envelope (a median floor cuts out long events like a passing
  truck), then normalise each event's loudest second to a common level (−24 dBFS).
- Run a separate seamless **bed** (wind, rain, distant traffic, ~−32 dBFS) under
  everything; −38 was inaudible under speech.
- Exclude the base loop's own soundtrack. It is louder than its events.

## Colour

- Encode with explicit tags (`-colorspace smpte170m -color_primaries smpte170m
  -color_trc smpte170m -color_range tv`) when the source is BT.601. Untagged 720p
  is read as BT.709 and oranges shift.
- If one player shows greyed-out video while the pixels match the source, suspect
  the player or GPU driver (an NVIDIA module/library mismatch forces a flat output
  path) before re-encoding.

## Operations

- Run generation resumably: skip existing outputs, one batch at a time, never
  two batches against the same quota.
- Stop a batch by PID (`ps -eo pid,args | grep "[p]ython3 …"`). `pkill -f pattern`
  matches its own shell and kills your command.
- Edit prompt files first, verify the edit landed, **then** launch. A failed text
  replacement plus an immediate launch spends money on the old prompt.
