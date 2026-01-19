#!/bin/bash
# Speak a brief summary of Claude's response when it finishes

# Find the transcript file from CLAUDE_PROJECT_DIR
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
    # Convert project dir to transcript folder name (e.g., /home/user/proj -> -home-user-proj)
    PROJ_FOLDER=$(echo "$CLAUDE_PROJECT_DIR" | sed 's|/|-|g' | sed 's|\.|-|g')
    TRANSCRIPT_DIR="$HOME/.claude/projects/$PROJ_FOLDER"

    # Get the most recently modified transcript file
    if [ -d "$TRANSCRIPT_DIR" ]; then
        TRANSCRIPT_PATH=$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
    fi
fi

# Extract the last assistant message from the transcript
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Get text from the last assistant message that contains text
    RAW_TEXT=$(jq -s -r '
        [.[] | select(.type == "assistant") |
         select(.message.content | if type == "array" then any(.[]; .type == "text") else true end)
        ] | last |
        .message.content |
        if type == "array" then
            [.[] | select(.type == "text") | .text] | join(" ")
        else
            .
        end // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    if [ -n "$RAW_TEXT" ]; then
        # Extract content from <summary>...</summary> tags if present
        MESSAGE=$(echo "$RAW_TEXT" | grep -oP '(?<=<summary>).*(?=</summary>)' | head -1)

        # Clean up for speech: remove any remaining markdown
        if [ -n "$MESSAGE" ]; then
            MESSAGE=$(echo "$MESSAGE" | \
                sed 's/\*\*//g' | \
                sed 's/\*//g' | \
                sed 's/`[^`]*`//g' | \
                sed 's/%/ percent/g' | \
                tr '\n' ' ' | \
                sed 's/  */ /g')
        fi
    fi
fi

# If no text content, just exit silently
if [ -z "$MESSAGE" ] || [ "$MESSAGE" = " " ]; then
    exit 0
fi

# Escape quotes for JSON
MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')

# Call turbo-tts API and play the audio
curl -s -X POST "http://192.168.1.89:8103/api/tts" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$MESSAGE\"}" \
    -o "$HOME/.claude/tts-output.wav" 2>/dev/null

# Speed up audio by 20% and play
ffmpeg -y -i "$HOME/.claude/tts-output.wav" -filter:a "atempo=1.2" "$HOME/.claude/tts-fast.wav" 2>/dev/null
aplay "$HOME/.claude/tts-fast.wav" 2>/dev/null || paplay "$HOME/.claude/tts-fast.wav" 2>/dev/null

exit 0
