# Troubleshooting

| Problem | Solution |
|---------|----------|
| No audio plays | Check TTS server is running: `curl -s http://192.168.1.89:8103/api/tts -X POST -H "Content-Type: application/json" -d '{"text":"test"}'` |
| Hear fallback text or nothing | Ensure Claude's response contains a `<summary>` block |
| "jq: parse error" | Transcript is JSONL format - ensure script uses `jq -s` to slurp lines into array |
| TRANSCRIPT_PATH is empty | Stop hooks don't receive this variable - derive path from `CLAUDE_PROJECT_DIR` instead |
| Wrong transcript folder | Path conversion must replace both `/` and `.` with `-` |
| Audio too slow/fast | Adjust `atempo` value in ffmpeg command (1.2 = 20% faster) |
| `%` not spoken as "percent" | Add `sed 's/%/ percent/g'` to text cleanup pipeline |
| sed errors on Linux | Don't use `m` flag (e.g., `sed 's/pattern//gm'`) - standard sed doesn't support multiline flag |
| Script works manually but not as hook | Check hook command uses `$HOME` not `~` (tilde may not expand in JSON) |
| Windows: script won't run | Add `-ExecutionPolicy Bypass` to PowerShell command |
| ffmpeg not found | Install ffmpeg or remove speed adjustment (script will use original speed) |
