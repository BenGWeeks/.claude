#!/usr/bin/env python3
"""Generate one video clip with Google Veo 3.1 (Gemini API), optionally pinned
to a first AND last frame so clips stitch together exactly.

    python3 generate.py --prompt-file shot.txt --first plate.png [--last plate.png] \
        --out clip.mp4 [--fast] [--seconds 8] [--max-gbp 5] [--yes]

Spends money. Prints a cost estimate first and refuses to run unless --yes is
given AND the estimate is within --max-gbp. The key is never printed.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = 'https://generativelanguage.googleapis.com/v1beta'
MODELS = {'standard': 'veo-3.1-generate-preview', 'fast': 'veo-3.1-fast-generate-preview'}
#: Conservative list prices per second of video WITH audio, in US$. Check
#: https://ai.google.dev/gemini-api/docs/pricing before trusting them: on
#: 2026-09-24/25 about 60 standard 8 s clips cost more than this estimated.
USD_PER_SECOND = {'standard': 0.75, 'fast': 0.40}
GBP_PER_USD = 0.79
NEGATIVE = ('cartoon, animation, illustration, text, captions, watermark, logo, camera shake, '
            'zoom, pan, cut, morphing, duplicate characters')


def key() -> str:
    """GEMINI_API_KEY from the environment, else ~/.config/gemini/api_key. Never printed."""
    value = os.environ.get('GEMINI_API_KEY', '').strip()
    if not value:
        path = Path.home() / '.config/gemini/api_key'
        if path.is_file():
            value = path.read_text().strip()
    if not value:
        raise SystemExit('No Gemini key: set GEMINI_API_KEY or write ~/.config/gemini/api_key (mode 600).')
    return value


def request(method: str, url: str, body: dict | None = None, timeout: int = 120) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={'Content-Type': 'application/json', 'x-goog-api-key': key()})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors='replace')[:400]
        # 402: prepaid credit exhausted. 429: quota (free tier has NO Veo).
        # 400 "use case not supported": a lastFrame needs --seconds 8.
        raise SystemExit(f'HTTP {error.code} from {url}: {detail}')


def image(path: Path) -> dict:
    mime = 'image/png' if path.suffix.lower() == '.png' else 'image/jpeg'
    return {'bytesBase64Encoded': base64.b64encode(path.read_bytes()).decode(), 'mimeType': mime}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    text = ap.add_mutually_exclusive_group(required=True)
    text.add_argument('--prompt')
    text.add_argument('--prompt-file', type=Path)
    ap.add_argument('--first', type=Path, required=True, help='first frame (16:9, e.g. 1280x720 PNG)')
    ap.add_argument('--last', type=Path, help='last frame; needs --seconds 8')
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--seconds', type=int, choices=(4, 6, 8), default=8)
    ap.add_argument('--fast', action='store_true', help='Veo 3.1 Fast: drafts and iteration')
    ap.add_argument('--resolution', choices=('720p', '1080p'), default='720p')
    ap.add_argument('--max-gbp', type=float, default=5.0, help='refuse if the estimate is above this')
    ap.add_argument('--yes', action='store_true', help='actually spend the money')
    args = ap.parse_args()

    if args.last is not None and args.seconds != 8:
        raise SystemExit('A pinned last frame needs --seconds 8 (Veo answers 400 "use case not supported").')
    if args.out.exists():
        print(f'{args.out} exists; not regenerating (move it aside to retake).')
        return 0
    tier = 'fast' if args.fast else 'standard'
    estimate = args.seconds * USD_PER_SECOND[tier] * GBP_PER_USD
    print(f'Estimate: {MODELS[tier]}, {args.seconds} s -> about GBP {estimate:.2f} '
          f'(list-price guess; check the Spend page).')
    if estimate > args.max_gbp:
        raise SystemExit(f'Refused: estimate GBP {estimate:.2f} is above --max-gbp {args.max_gbp:.2f}.')
    if not args.yes:
        print('Dry run: add --yes to generate.')
        return 0

    prompt = args.prompt if args.prompt is not None else args.prompt_file.read_text().strip()
    instance = {'prompt': prompt, 'image': image(args.first)}
    if args.last is not None:
        instance['lastFrame'] = image(args.last)
    body = {'instances': [instance],
            'parameters': {'aspectRatio': '16:9', 'resolution': args.resolution,
                           'durationSeconds': args.seconds, 'negativePrompt': NEGATIVE,
                           'personGeneration': 'allow_adult'}}
    operation = request('POST', f'{API}/models/{MODELS[tier]}:predictLongRunning', body)
    name = operation['name']
    print(f'started {name}', flush=True)
    for _ in range(120):
        time.sleep(10)
        operation = request('GET', f'{API}/{name}')
        if operation.get('done'):
            break
    else:
        raise SystemExit('not finished after 20 minutes')
    if 'error' in operation:
        raise SystemExit(f'Veo error: {operation["error"].get("message", operation["error"])}')
    response = operation.get('response', {})
    samples = (response.get('generateVideoResponse') or response).get('generatedSamples') or []
    if not samples:
        raise SystemExit(f'finished with no video (filtered?): {json.dumps(response)[:400]}')
    req = urllib.request.Request(samples[0]['video']['uri'], headers={'x-goog-api-key': key()})
    with urllib.request.urlopen(req, timeout=600) as download:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(download.read())
    print(f'wrote {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
