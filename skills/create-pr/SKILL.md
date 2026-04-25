---
name: create-pr
description: Create a GitHub pull request from the current branch with optional emulator screenshots committed to the repo and referenced inline. Use when the user says "create a PR", "open a PR", or asks for screenshots in a PR description. Spawns a screenshot sub-agent for the redact + commit + reference steps so the main thread stays clean.
allowed-tools: Bash, Read, Write, Edit, Agent
---

# Create Pull Request Skill

Open a PR from the current branch on `gh`-authed GitHub, with optional automated screenshot embedding.

## When to use this skill

- User says "create a PR", "open a PR", "raise a PR" against a branch.
- User mentions wanting screenshots in the PR (description or comment).
- User has just made a UI change on a feature branch and wants to ship it for review.

## Pre-flight checks (always)

Before calling `gh pr create`:

1. **Branch state** — run these in parallel:
   - `git status` — confirm no merge conflicts, no unstaged work the user expected to push.
   - `git log --oneline <base>..HEAD` — show what's actually going into the PR.
   - `git fetch origin <base> && git log --oneline origin/<base>..HEAD` — same but against the remote, confirms the branch is pushed.
   - `git diff <base>...HEAD --stat` — get a feel for the change footprint.

2. **Draft the title** (Conventional Commits + issue suffix per the project's CLAUDE.md):
   `<type>(<scope>): <imperative description> (#<issue>)`
   Examples:
   - `feat(messaging): inline attach panel above text input (#100)`
   - `fix(receive): hide back arrow on amount-only flow (#168)`

3. **Draft the body** with this structure:
   ```
   ## Summary
   <2–4 sentence what + why>

   ## Screenshots
   <only if there are UI changes — see "Screenshot embedding" below>

   ## How it works
   <one para to one bullet list, only if non-obvious>

   ## Files
   <bulleted "Added/Modified/Deleted" list — be terse>

   ## Test plan
   <maestro test commands + bullet checklist of what each covers>
   ```

## Screenshot embedding (the optional part)

When the user wants screenshots in the PR, **delegate the redact-and-attach work to a sub-agent**. Don't do it inline — it's mechanical and pollutes the main context with image data.

### Decision: gist vs in-repo commit

There are two ways to host images so they render in PR markdown:
- **Public gist** — fast, but **uploads to public storage**. Permission systems may block this as data exfiltration. Don't default to it.
- **In-repo commit** under `docs/screenshots/PR-<number>/` — slower (one extra commit), but the images live with the code, are diff-reviewable, and don't escape the repo's permission boundary.

**Default to in-repo commit.** Only fall back to gist if the user explicitly says "use a gist" or the repo is read-only.

### Sub-agent prompt template

After running `gh pr create` and capturing the PR number from the URL, spawn:

```
Agent({
  description: "Attach + redact screenshots for PR #<n>",
  subagent_type: "general-purpose",
  prompt: """
You're attaching screenshots to PR #<n> on <owner>/<repo>.

Source files:
  <list of /tmp/*.png paths the main thread captured>

Steps:

1. Identify any personal/identifying content in each screenshot:
   - Real contact names in a chat header (NOT test fixtures like 'Big Piggy' / 'Little Piggy' / 'LightningPiggy')
   - Real avatars / faces (anything that isn't a default placeholder)
   - Real Lightning amounts (anything that isn't a fixture invoice/zap of a small round number)
   - Real lud16 lightning addresses, npubs, nip05 identifiers
   - Real DM message content (NOT obviously generic test strings like 'Hello, World!' or 'kbtest')

2. Black out each identified region using ImageMagick:
     convert input.png -fill black -draw 'rectangle X1,Y1 X2,Y2' [-draw ...] output.png
   Use uiautomator dump if you need exact pixel bounds; otherwise eyeball coords (screen is 540x1200 px after the standard /tmp/ resize).

3. Copy the redacted PNGs into the repo at:
     docs/screenshots/PR-<n>/01-<descriptive-name>.png
     docs/screenshots/PR-<n>/02-<descriptive-name>.png
     ...

4. Commit + push to the PR's branch:
     git add docs/screenshots/PR-<n>/
     git commit -m "docs(screenshots): PR-<n> attachments (redacted)"
     git push

5. Edit the PR description to insert a Screenshots section with raw.githubusercontent.com markdown image URLs:

   ## Screenshots

   | <state 1> | <state 2> | <state 3> |
   |---|---|---|
   | ![](https://raw.githubusercontent.com/<owner>/<repo>/<branch>/docs/screenshots/PR-<n>/01-<name>.png) | ... |

   Use `gh pr edit <n> --body "$(cat <<'EOF' ... EOF)"` with the new full body. Preserve the rest of the description that the main thread already wrote.

6. Report back: which regions you redacted in each image, how many pixels you covered, the final commit SHA. Under 200 words.

Constraints:
- Do NOT upload images to a public gist or any external host.
- Do NOT commit unredacted versions, even temporarily.
- Do NOT post screenshots as a PR comment if the description already has a Screenshots section (avoid duplication).
- Do NOT modify any source code, only the docs/screenshots/ directory and the PR description text.
"""
})
```

The sub-agent isolates the per-screenshot judgement calls (which regions to redact, exact pixel bounds, ImageMagick command tuning) so the main thread doesn't have to render the images repeatedly.

## After creation

1. Print the PR URL (returned by `gh pr create`).
2. If screenshots were attached, print the filenames committed.
3. **If the PR is NOT a draft, request a GitHub Copilot code review** — see "Requesting Copilot review" below.
4. **Wait for the Copilot review to land, then chain into the `fix-copilot-review` skill** — see "Chaining into fix-copilot-review" below.
5. Don't auto-merge. Don't request human reviewers. Wait for the user.

## Requesting Copilot review

GitHub Copilot only reviews PRs that are **ready for review** (it skips drafts). Trigger the review automatically once the PR is out of draft.

### Why not just `gh pr edit --add-reviewer Copilot`

That works on `gh ≥ 2.88` (released March 2026). On older versions it silently fails because the REST endpoint `POST /pulls/{n}/requested_reviewers` only accepts User and Team logins — bots have to go through a separate GraphQL mutation. Detect the gh version and fall back if needed:

```sh
gh_major=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)
gh_minor=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)
```

### gh ≥ 2.88

```sh
gh pr edit <n> --add-reviewer @copilot
```

### gh < 2.88 — GraphQL mutation (works on every version)

```sh
PR_NODE=$(gh pr view <n> --json id -q .id)
gh api graphql -f query='
mutation($pr: ID!) {
  requestReviewsByLogin(input: {
    pullRequestId: $pr,
    botLogins: ["copilot-pull-request-reviewer"],
    union: true
  }) {
    pullRequest { number }
  }
}' -f pr="$PR_NODE"
```

`union: true` adds Copilot without removing existing reviewers (safe to re-run).

### Verifying the request landed

`gh pr view <n> --json reviewRequests` **omits bot reviewers** — it only enumerates Users. To confirm Copilot is attached, query GraphQL:

```sh
gh api graphql -f query='
{
  repository(owner: "<owner>", name: "<repo>") {
    pullRequest(number: <n>) {
      reviewRequests(first: 10) {
        nodes {
          requestedReviewer {
            __typename
            ... on Bot { login }
            ... on User { login }
          }
        }
      }
    }
  }
}'
```

A successful response includes `{"__typename":"Bot","login":"copilot-pull-request-reviewer"}`.

### Requirements

The repo owner needs **Copilot Pro, Pro+, Business, or Enterprise** with code review enabled (account-level: https://github.com/settings/copilot/features, repo-level: `<repo>/settings/copilot/code_review`). If the request returns `200` with an empty `reviewRequests`, code review isn't enabled — surface that to the user with the settings URLs above. Don't keep retrying.

### When NOT to request Copilot review

- PR is a draft (Copilot won't review it; the request would still be attached but won't fire until ready).
- User said "no review", "skip review", or has previously declined Copilot reviews in the same session — record that as a feedback memory.
- The change is `chore`-scope-only and trivially mechanical (pure formatting, dependency bump with no code change).

## Chaining into fix-copilot-review

After requesting a Copilot review, **wait for the review to actually post**, then invoke the `fix-copilot-review` skill so the loop closes without the user having to ask twice.

### Polling cadence

Copilot reviews typically post **1–4 minutes** after the request. Use `ScheduleWakeup` (preferred) or a short polling loop with these parameters:
- **First check:** ~90 seconds after request.
- **Subsequent checks:** every ~120 seconds.
- **Give-up timeout:** ~10 minutes total. If nothing has landed by then, surface "Copilot hasn't reviewed yet — re-request or check the PR page" and stop.

Don't busy-loop on a tight `sleep`. `ScheduleWakeup` keeps the cache warm and doesn't burn tokens during the wait.

### How to detect that the review landed

```sh
gh api graphql -f query='
{
  repository(owner: "<owner>", name: "<repo>") {
    pullRequest(number: <n>) {
      reviews(first: 10, author: {login: "copilot-pull-request-reviewer"}) {
        nodes { state submittedAt body }
      }
      reviewThreads(first: 50) {
        nodes {
          comments(first: 1) {
            nodes { author { login } }
          }
        }
      }
    }
  }
}'
```

The review has landed when **either**:
- `reviews.nodes` contains an entry with `submittedAt` set (a top-level review summary), **or**
- `reviewThreads.nodes` contains threads whose first comment is authored by `copilot-pull-request-reviewer` (inline comments — Copilot sometimes posts these without a wrapping review).

If neither is present yet, schedule another wakeup.

### Once the review has landed

Invoke the `fix-copilot-review` skill via the `Skill` tool, passing the PR number:

```
Skill({ skill: "fix-copilot-review", args: "<n>" })
```

That skill knows how to fetch each comment, fix the underlying code, and reply per-comment. Don't try to short-circuit it by reading comments inline here.

### When NOT to chain

- User said "just open the PR" / "don't fix the review" / "I'll handle the review myself".
- Copilot review wasn't requested in step 3 (no review to wait for).
- The repo doesn't have Copilot code review enabled (the request returned 200 with empty `reviewRequests`).

## Things NOT to do

- Don't use `gh pr create --draft` unless the user said "draft PR".
- Don't add `Co-Authored-By` lines unless the user explicitly mentioned that style.
- Don't push images to a public gist by default (data exfiltration risk).
- Don't take fresh screenshots from the device just to attach — assume the user has already grabbed what they want under `/tmp/` during their interactive session. If there are none, ask whether to capture some.
- Don't cap the PR description length; GitHub handles long bodies fine.
- Don't request **human** reviewers automatically — only Copilot. Humans get pulled in by the user.

## Example: full flow

```
1. git status, git log, git diff --stat → confirm branch is ready
2. Draft title + body locally (no screenshots block yet)
3. gh pr create --title "..." --body "$(cat <<'EOF' ... EOF)"
4. Capture PR URL → extract PR number
5. If user mentioned screenshots:
   - Identify /tmp/*.png files captured during this session
   - Spawn sub-agent (above prompt) to redact + commit + edit description
6. If PR is NOT a draft → request Copilot review (GraphQL mutation
   above for gh < 2.88, otherwise `gh pr edit <n> --add-reviewer @copilot`)
7. Print PR URL
8. Wait for Copilot review to land (ScheduleWakeup, ~90s then 120s
   intervals up to ~10min) → invoke `Skill({ skill: "fix-copilot-review", args: "<n>" })`
```
