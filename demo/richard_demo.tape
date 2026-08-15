# 🎬 Richard Console Demo — VHS Tape
# Records a beautiful terminal demo of the Antigravity Ruby SDK console.
# Usage: vhs demo/richard_demo.tape
#
# Output: demo/richard_demo.mp4 + demo/richard_demo.gif

Output demo/richard_demo.mp4
Output demo/richard_demo.gif

# ─── Terminal Setup ───────────────────────────────────────
Set FontSize 16
Set FontFamily "JetBrains Mono"
Set Width 1400
Set Height 800
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 50ms
Set PlaybackSpeed 1

# ─── Run the fake console demo ───────────────────────────
Type "ruby demo/vhs_fake_console.rb"
Enter
Sleep 45s

# Wait for script to finish
Sleep 2s
