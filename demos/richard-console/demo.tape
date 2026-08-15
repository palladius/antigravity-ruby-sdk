# 🎬 Richard Console Demo — REAL VHS Tape
# Drives the ACTUAL console. LLM responses are non-deterministic
# but we don't care — the demo is about the console features!
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
# ACT 2: Quick LLM chat (we don't care what it says)
# ═══════════════════════════════════════════════════════════
Type "Hello! What can you do?"
Enter
Sleep 12s

# ═══════════════════════════════════════════════════════════
# ACT 3: Shell + Ruby eval (deterministic!)
# ═══════════════════════════════════════════════════════════
Type "! pwd"
Enter
Sleep 2s

Type "r! Antigravity::VERSION"
Enter
Sleep 2s

Type "r! RUBY_VERSION"
Enter
Sleep 2s

# ═══════════════════════════════════════════════════════════
# ACT 4: /irb — THE MATRIX (100% deterministic!)
# ═══════════════════════════════════════════════════════════
Type "/irb"
Enter
Sleep 2s

# Full config hash
Type "config"
Enter
Sleep 2s

# Ruby power: .select on hash
Type "config.select { |k,_| [:version, :workspace, :model].include?(k) }"
Enter
Sleep 2s

# Policy introspection
Type "Antigravity::Policy::SAFE_CMDS"
Enter
Sleep 2s

Type "Antigravity::Policy::CATASTROPHIC_CMDS"
Enter
Sleep 2s

# Smart setters
Type "cd '~/git'"
Enter
Sleep 1s

Type "set_policy :turbo"
Enter
Sleep 1s

Type "config.select { |k,_| [:workspace, :policy].include?(k) }"
Enter
Sleep 2s

# Reset
Type "cd '~/git/antigravity-ruby-sdk'"
Enter
Sleep 1s

Type "set_policy :console"
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
