# 🎬 Richard Console Demo — REAL VHS Tape v8
# Drives the ACTUAL console with live Gemini API.
#
# ⚠️ VHS QUOTING RULES (learned the hard way x7):
#   - NO single quotes (VHS eats them as string delimiters)
#   - NO %() %[] %{} (VHS eats % + grouping chars)
#   - Use File.join(Dir.home, :symbol.to_s) for paths
#   - Use 128994.chr(Encoding::UTF_8) for 🟢 emoji
#   - Use 128308.chr(Encoding::UTF_8) for 🔴 emoji
#
# Usage: cd ~/git/antigravity-ruby-sdk && vhs demos/richard-console/demo.tape

Output demos/richard-console/demo.mp4
Output demos/richard-console/demo.gif

# ─── Terminal Setup ───────────────────────────────────────
Set FontSize 14
Set FontFamily "Menlo"
Set Width 1100
Set Height 700
Set Padding 16
Set Theme "Dracula"
Set TypingSpeed 50ms
Set PlaybackSpeed 1
Set LetterSpacing 0

# ═══════════════════════════════════════════════════════════
# ACT 1: Launch console
# ═══════════════════════════════════════════════════════════
Type "rv run ruby examples/10_console.rb"
Enter
Sleep 10s

# ═══════════════════════════════════════════════════════════
# ACT 2: Quick LLM chat
# ═══════════════════════════════════════════════════════════
Type "Hello! What can you do?"
Enter
Sleep 8s

# ═══════════════════════════════════════════════════════════
# ACT 3: Shell + Ruby eval (deterministic!)
# ═══════════════════════════════════════════════════════════
Type "! pwd"
Enter
Sleep 2s

Type "r! Antigravity::VERSION"
Enter
Sleep 2s

# ═══════════════════════════════════════════════════════════
# ACT 4: /irb — THE MATRIX
# ═══════════════════════════════════════════════════════════
Type "/irb"
Enter
Sleep 2s

# Config slice — show workspace_analysis is ON
Type "config.select { |k,_| [:version, :model, :workspace_analysis].include?(k) }"
Enter
Sleep 2s

# 🟢🔴 Policy visualization WITH EMOJI!
# 128994 = 🟢 U+1F7E2, 128308 = 🔴 U+1F534
Type "Antigravity::Policy::SAFE_CMDS.each { |c| puts 128994.chr(Encoding::UTF_8) + c.to_s }"
Enter
Sleep 3s

Type "Antigravity::Policy::CATASTROPHIC_CMDS.each { |c| puts 128308.chr(Encoding::UTF_8) + c.to_s }"
Enter
Sleep 3s

# ═══════════════════════════════════════════════════════════
# ACT 5: 🌟 Workspace Discovery — THE WOW MOMENT
# ═══════════════════════════════════════════════════════════

# Save current workspace for later
Type "home_sdk = @workspace"
Enter
Sleep 1s

# cd to ~/git — triggers 📊 scan + 🤖 LLM analysis!
Type "cd(File.join(Dir.home, :git.to_s))"
Enter
Sleep 12s

# cd back to the SDK — different scan results!
Type "cd(home_sdk)"
Enter
Sleep 12s

# Toggle analysis off
Type "set_workspace_analysis false"
Enter
Sleep 1s

# Exit Matrix
Type "exit"
Enter
Sleep 2s

# ═══════════════════════════════════════════════════════════
# FINALE
# ═══════════════════════════════════════════════════════════
Type "/quit"
Enter
Sleep 2s
