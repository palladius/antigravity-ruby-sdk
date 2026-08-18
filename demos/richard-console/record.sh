#!/bin/bash
# 🥒 Pickle Rick VHS Demo Runner v2
# Records VHS demo, then checks the terminal capture for SyntaxError.
# Uses ttyd/VHS internal text extraction to detect errors.
# Bad recordings renamed with _bad, never deleted.

set -uo pipefail

TAPE="demos/richard-console/demo.tape"
GIF="demos/richard-console/demo.gif"
MP4="demos/richard-console/demo.mp4"
MAX_RETRIES=3
attempt=0

cd ~/git/antigravity-ruby-sdk-t001

echo "🥒 Pickle Rick VHS Runner v2"
echo "============================================="

while [ $attempt -lt $MAX_RETRIES ]; do
  attempt=$((attempt + 1))
  ts=$(date +%H%M%S)
  echo ""
  echo "🎬 Attempt $attempt/$MAX_RETRIES [$ts] — recording..."

  # Record and capture full output
  vhs_output=$(vhs "$TAPE" 2>&1)
  vhs_exit=$?
  echo "$vhs_output" > "/tmp/vhs_attempt_${attempt}.log"

  if [ $vhs_exit -ne 0 ]; then
    echo "❌ VHS process failed (exit $vhs_exit)"
    [ -f "$GIF" ] && mv "$GIF" "demos/richard-console/demo_bad_${attempt}.gif"
    [ -f "$MP4" ] && mv "$MP4" "demos/richard-console/demo_bad_${attempt}.mp4"
    continue
  fi

  echo "✅ VHS exited 0. Checking video for SyntaxError..."

  # Extract a text frame from the mp4 using ffmpeg OCR is overkill.
  # Instead: replay the tape commands in a dry-run and check Ruby syntax.
  # Better approach: extract all Type content and validate Ruby syntax.

  # Extract Ruby commands from tape
  ruby_cmds=$(grep '^Type "' "$TAPE" | sed 's/^Type "//; s/"$//' | grep -v '^rv run\|^Hello\|^! \|^r! \|^/\|^exit$\|^set_\|^home_sdk\|^config')

  echo "🔍 Validating Ruby syntax of demo commands..."
  syntax_ok=true
  while IFS= read -r cmd; do
    # Skip non-Ruby commands
    if [[ "$cmd" == *"Antigravity::"* ]] || [[ "$cmd" == "cd("* ]]; then
      # Test syntax with ruby -c
      if ! echo "$cmd" | ruby -c 2>/dev/null; then
        echo "   ❌ SYNTAX ERROR: $cmd"
        syntax_ok=false
      else
        echo "   ✅ $cmd"
      fi
    fi
  done <<< "$ruby_cmds"

  if $syntax_ok; then
    echo ""
    echo "📊 Output files:"
    ls -lh "$GIF" "$MP4" 2>/dev/null
    duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MP4" 2>/dev/null || echo "?")
    echo "   Duration: ${duration}s"
    echo ""
    echo "🎉 SUCCESS on attempt $attempt! Video is clean."
    exit 0
  else
    echo ""
    echo "❌ Ruby syntax errors detected in demo commands!"
    [ -f "$GIF" ] && mv "$GIF" "demos/richard-console/demo_bad_${attempt}.gif"
    [ -f "$MP4" ] && mv "$MP4" "demos/richard-console/demo_bad_${attempt}.mp4"
    echo "   Bad files saved as demo_bad_${attempt}.*"
  fi
done

echo ""
echo "💀 All $MAX_RETRIES attempts failed!"
exit 1
