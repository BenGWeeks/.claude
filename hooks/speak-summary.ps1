# Speak a brief summary of Claude's response when it finishes (Windows PowerShell version)

# Find the transcript file from CLAUDE_PROJECT_DIR
$projectDir = $env:CLAUDE_PROJECT_DIR
if ($projectDir) {
    # Convert project dir to transcript folder name (e.g., C:\Users\ben\proj -> -C--Users-ben-proj)
    $projFolder = $projectDir -replace '[/\\]', '-' -replace '\.', '-' -replace ':', ''
    $transcriptDir = "$env:USERPROFILE\.claude\projects\$projFolder"

    # Get the most recently modified transcript file
    if (Test-Path $transcriptDir) {
        $transcriptPath = Get-ChildItem "$transcriptDir\*.jsonl" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

# Extract the last assistant message from the transcript
$message = $null
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    # Read all lines and parse as JSON array
    $lines = Get-Content $transcriptPath -Raw
    $jsonObjects = $lines -split "`n" | Where-Object { $_.Trim() } | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ }

    # Find the last assistant message with text content
    $assistantMessages = $jsonObjects | Where-Object { $_.type -eq 'assistant' }

    foreach ($msg in ($assistantMessages | Select-Object -Last 10 | Sort-Object -Descending)) {
        $content = $msg.message.content

        # Handle array content
        if ($content -is [Array]) {
            $textContent = ($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' '
        } else {
            $textContent = $content
        }

        if ($textContent) {
            # Extract content from <summary>...</summary> tags
            if ($textContent -match '<summary>(.*?)</summary>') {
                $message = $matches[1]
                break
            }
        }
    }
}

# If no summary found, exit silently
if (-not $message -or $message -eq ' ') {
    exit 0
}

# Clean up for speech
$message = $message -replace '\*\*', '' -replace '\*', '' -replace '`[^`]*`', '' -replace '%', ' percent'
$message = $message -replace '\s+', ' '
$message = $message.Trim()

# Escape quotes for JSON
$messageJson = $message -replace '"', '\"'

# TTS API endpoint
$ttsUrl = "http://192.168.1.89:8103/api/tts"
$outputFile = "$env:USERPROFILE\.claude\tts-output.wav"
$fastFile = "$env:USERPROFILE\.claude\tts-fast.wav"

# Call turbo-tts API
try {
    $body = @{ text = $message } | ConvertTo-Json
    Invoke-WebRequest -Uri $ttsUrl -Method POST -ContentType "application/json" -Body $body -OutFile $outputFile -ErrorAction Stop
} catch {
    exit 0
}

# Speed up audio by 20% with ffmpeg (if available)
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg -and (Test-Path $outputFile)) {
    & ffmpeg -y -i $outputFile -filter:a "atempo=1.2" $fastFile 2>$null
    if (Test-Path $fastFile) {
        $outputFile = $fastFile
    }
}

# Play the audio
if (Test-Path $outputFile) {
    $player = New-Object System.Media.SoundPlayer $outputFile
    $player.PlaySync()
}

exit 0
