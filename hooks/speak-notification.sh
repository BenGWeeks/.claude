#!/bin/bash
# Speak context-aware notifications when Claude needs input

# Get notification type from environment or argument
NOTIFICATION_TYPE="${CLAUDE_NOTIFICATION_TYPE:-$1}"

# Select message based on notification type
case "$NOTIFICATION_TYPE" in
    permission_prompt)
        MESSAGE="Permission required"
        ;;
    elicitation_dialog)
        MESSAGE="I have a question"
        ;;
    idle_prompt)
        MESSAGE="Ready for input"
        ;;
    pre_compact_auto)
        MESSAGE="Compacting context"
        ;;
    pre_compact_manual)
        MESSAGE="Compacting"
        ;;
    *)
        # Unknown type, exit silently
        exit 0
        ;;
esac

# Call turbo-tts API
curl -s -X POST "http://192.168.1.89:8103/api/tts" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$MESSAGE\"}" \
    -o "$HOME/.claude/tts-notification.wav" 2>/dev/null

# Speed up and play
if [ -f "$HOME/.claude/tts-notification.wav" ]; then
    ffmpeg -y -i "$HOME/.claude/tts-notification.wav" -filter:a "atempo=1.2" "$HOME/.claude/tts-notification-fast.wav" 2>/dev/null
    aplay "$HOME/.claude/tts-notification-fast.wav" 2>/dev/null || paplay "$HOME/.claude/tts-notification-fast.wav" 2>/dev/null
fi

exit 0
