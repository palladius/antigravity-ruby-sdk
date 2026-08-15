# 🎬 Richard Console Demo — VHS Tape
# Records the Antigravity Ruby SDK console showcase.
# Usage: cd ~/git/antigravity-ruby-sdk-t001 && vhs demo/richard_demo.tape
#
# Output: demo/richard_demo.mp4 + demo/richard_demo.gif

Output demo/richard_demo.mp4
Output demo/richard_demo.gif

# ─── Terminal Setup ───────────────────────────────────────
Set FontSize 15
Set FontFamily "JetBrains Mono"
Set Width 1200
Set Height 700
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 0ms
Set PlaybackSpeed 1

# ─── Run the fake console demo ───────────────────────────
Type "ruby demo/vhs_fake_console.rb"
Enter
Sleep 38s

# Wait for script to finish gracefully
Sleep 3s
