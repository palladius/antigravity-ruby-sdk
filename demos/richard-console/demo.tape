# 🎬 Richard Console Demo — REAL VHS Tape v6
# Drives the ACTUAL console with live Gemini API.
# RULE: NO SINGLE QUOTES in Type commands! VHS eats them.
# NEW: Workspace discovery on cd (scan + LLM analysis)
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

# Config slice
Type "config.select { |k,_| [:version, :model, :workspace_analysis].include?(k) }"
Enter
Sleep 2s

# 🟢🔴 Policy visualization
Type "Antigravity::Policy::SAFE_CMDS.each { |c| puts %(  🟢 ) + c.to_s }"
Enter
Sleep 3s

Type "Antigravity::Policy::CATASTROPHIC_CMDS.each { |c| puts %(  🔴 ) + c.to_s }"
Enter
Sleep 3s

# ═══════════════════════════════════════════════════════════
# ACT 5: 🌟 Workspace Discovery — THE WOW MOMENT
# ═══════════════════════════════════════════════════════════

# cd to a different project — triggers scan + LLM analysis!
Type "cd %(~/git/ricc.rocks)"
Enter
Sleep 12s

# cd back — different scan results!
Type "cd %(~/git/antigravity-ruby-sdk)"
Enter
Sleep 12s

# Show it can be toggled off
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
