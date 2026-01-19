# .claude

Personal Claude Code configuration and customizations.

## TTS Voice Summary

Claude speaks a summary of each response using text-to-speech via a turbo-tts server.

### How it Works

1. Claude includes a `<summary>` block at the end of each response
2. A Stop hook extracts the summary text
3. The text is sent to the turbo-tts API
4. Audio is sped up 20% and played back

### Files

| File | Purpose |
|------|---------|
| `hooks/speak-summary.sh` | Linux bash script for summaries |
| `hooks/speak-summary.ps1` | Windows PowerShell script for summaries |
| `hooks/speak-notification.sh` | Linux script for input notifications |
| `settings.json` | Hook configuration |
| `CLAUDE.md` | Instructions for Claude to include summaries |

## Input Notifications

Speaks context-aware messages when Claude needs user input.

| Notification Type | Message |
|-------------------|---------|
| `permission_prompt` | "Permission required" |
| `elicitation_dialog` | "I have a question" |
| `idle_prompt` | "Ready for input" |

### Configuration

**Linux** (`settings.json`):
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/speak-summary.sh"
          }
        ]
      }
    ]
  }
}
```

**Windows** (`settings.json`):
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\hooks\\speak-summary.ps1"
          }
        ]
      }
    ]
  }
}
```

### Requirements

| Dependency | Linux | Windows |
|------------|-------|---------|
| TTS Server | turbo-tts at `192.168.1.89:8103` | Same |
| JSON Parser | `jq` | Built-in |
| Audio Speed | `ffmpeg` (optional) | `ffmpeg` (optional) |
| Audio Player | `aplay` or `paplay` | Built-in |

### TTS API

- **Endpoint**: `POST http://192.168.1.89:8103/api/tts`
- **Body**: `{"text": "your text"}`
- **Returns**: WAV audio file

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
