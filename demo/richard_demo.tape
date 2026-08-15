# 🎬 Richard Console Demo — VHS Tape
# Usage: cd ~/git/antigravity-ruby-sdk-t001 && vhs demo/richard_demo.tape
#
# Output: demo/richard_demo.mp4 + demo/richard_demo.gif

Output demo/richard_demo.mp4
Output demo/richard_demo.gif

# ─── Terminal Setup ───────────────────────────────────────
Set FontSize 14
Set FontFamily "Menlo"
Set Width 1100
Set Height 650
Set Padding 16
Set Theme "Dracula"
Set TypingSpeed 0ms
Set PlaybackSpeed 1
Set LetterSpacing 0

# ─── Run the fake console demo ───────────────────────────
Type "ruby demo/vhs_fake_console.rb"
Enter
Sleep 38s

# Wait for script to finish gracefully
Sleep 3s
