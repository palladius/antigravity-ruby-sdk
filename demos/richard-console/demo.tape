# 🎬 Richard Console Demo — REAL VHS Tape v7
# Drives the ACTUAL console with live Gemini API.
#
# ⚠️ VHS QUOTING RULES (learned the hard way):
#   - NO single quotes in Type commands (VHS eats them as string delimiters)
#   - NO %() %[] %{} in Type commands (VHS eats % + grouping chars)
#   - Use Ruby symbols :foo.to_s, ?/ char literals, and Dir.home instead
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

# 🟢🔴 Policy — show raw arrays (no string literals!)
Type "Antigravity::Policy::SAFE_CMDS"
Enter
Sleep 2s

Type "Antigravity::Policy::CATASTROPHIC_CMDS"
Enter
Sleep 2s

# ═══════════════════════════════════════════════════════════
# ACT 5: 🌟 Workspace Discovery — THE WOW MOMENT
# No string literals needed! Dir.home + ?/ + :symbol.to_s
# ═══════════════════════════════════════════════════════════

# Save current workspace for later
Type "home_sdk = @workspace"
Enter
Sleep 1s

# cd to ~/git — triggers 📊 scan + 🤖 LLM analysis!
Type "cd(Dir.home + ?/ + :git.to_s)"
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
