---
description: Edit or reset the Claude Code statusline configuration
---

Help me with my Claude Code statusline. If no specific changes are requested, set up the statusline exactly as specified below.

**Setup requires two files:**

1. `~/.claude/settings.json` must include:
```json
{
  "statusLine": {
    "type": "command",
    "command": "/home/benw/.claude/statusline-command.sh"
  }
}
```

2. `~/.claude/statusline-command.sh` (must be executable with `chmod +x`):
```bash
#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract basic info
user=$(whoami)
host=$(hostname -s)
dir=$(pwd)
model=$(echo "$input" | jq -r '.model.display_name')

# Calculate context usage percentage and create progress bar
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    pct=$((current * 100 / size))

    # Create progress bar (20 characters wide)
    bar_width=20
    filled=$((pct * bar_width / 100))
    empty=$((bar_width - filled))

    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    progress_info=$(printf " %s %d%%" "$bar" "$pct")
else
    progress_info=""
fi

# Print formatted status line with colors
# Green for user@host, blue for directory, cyan for model, yellow for progress
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m \033[01;36m[%s]\033[00m\033[01;33m%s\033[00m' \
    "$user" "$host" "$dir" "$model" "$progress_info"
```

**Display format:** `user@host:directory [Model] ████████░░░░░░░░░░░░ 40%`
- Green: username@hostname
- Blue: current directory
- Cyan: [Model Name]
- Yellow: progress bar and percentage

$ARGUMENTS
