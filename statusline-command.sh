#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract basic info
user=$(whoami)
host=$(hostname -s)
dir=$(pwd)
model=$(echo "$input" | jq -r '.model.display_name')

# Get Claude Code version
claude_version=$(claude --version 2>/dev/null | head -1 | awk '{print $1}' || echo "?")

# Get current Git branch (if in a git repo)
git_branch=$(git branch --show-current 2>/dev/null)
if [ -n "$git_branch" ]; then
    git_info=" 🌿 $git_branch"
else
    git_info=""
fi

# Context bar (shows % left until auto-compact)
progress_info=""
context_usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$context_usage" != "null" ]; then
    current=$(echo "$context_usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')

    # Autocompact buffer is ~22.5% of total context
    autocompact_buffer=$((size * 225 / 1000))

    # Calculate space left until auto-compact triggers
    free=$((size - current))
    left_until_compact=$((free - autocompact_buffer))

    # Clamp to 0 if negative
    if [ "$left_until_compact" -lt 0 ]; then
        left_until_compact=0
    fi

    pct=$((left_until_compact * 100 / size))

    # Create progress bar (20 characters wide)
    bar_width=20
    filled=$((pct * bar_width / 100))
    empty=$((bar_width - filled))

    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # Color based on remaining: green (>25%), amber (5-25%), red (<5%)
    if [ "$pct" -gt 25 ]; then
        bar_color="\033[01;32m"  # Green
    elif [ "$pct" -gt 5 ]; then
        bar_color="\033[01;33m"  # Amber
    else
        bar_color="\033[01;31m"  # Red
    fi

    progress_info=$(printf " ${bar_color}%s %d%%\033[00m" "$bar" "$pct")
fi

# Print formatted status line
# Format: user@host:directory 💻 version 🤖 Model 🌿 branch [progress bar]
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m 💻 %s 🤖 \033[01;36m%s\033[00m%s%s' \
    "$user" "$host" "$dir" "$claude_version" "$model" "$git_info" "$progress_info"
