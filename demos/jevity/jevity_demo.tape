# 🎈 Jevity (rujev) demo: JEV-powered levity for your Ruby Antigravity agents: Gemini answers, JEV System One guards every command.
# Replays Riccardo's real session (2026-10-08), translated to English.
#
#   just demo-jevity        # builds the sandbox + records (run from repo root)
#
# Rules (see demo-agentic-video skill): NO single quotes / backticks / %() in Type.

Output jevity_demo.mp4
Output jevity_demo.gif

Set Shell "bash"
Set FontSize 20
Set Width 1400
Set Height 900
Set Padding 24
Set Theme "TokyoNight"
Set TypingSpeed 45ms
Set PlaybackSpeed 1
Set WindowBar Colorful

# ── hidden setup: use this repo bin/, jump into the sandbox ────────────────
Hide
Type "export PATH=$PWD/../../bin:$PATH && cd /tmp/jevity-demo/.agents/rules && clear"
Enter
Sleep 1s
Show

Type "# Jevity: JEV-powered levity for your Ruby Antigravity agents (run as rujev)"
Sleep 800ms
Enter
Sleep 600ms

Type "rujev"
Enter
Sleep 2s

# 1. Natural language -> answered from workspace context
Type "what is in here?"
Enter
Sleep 6s

# 2. Destructive command -> BLOCKED by JEV
Type "rm gicbin-script.md"
Enter
Sleep 3s

# 3. Secret exfiltration -> BLOCKED by JEV
Type "cat ../../.env"
Enter
Sleep 3s

# 4. Safe command -> APPROVED and executed
Type "git status"
Enter
Sleep 3500ms

# 5. Model proposes a command, JEV approves it, model reads the output
Type "how many files are in this repo?"
Enter
Sleep 7s

# 6. Multi-turn memory: "its" refers to the previous question
Type "now cd to the git root and count all tracked files there"
Enter
Sleep 8s

Type "exit"
Enter
Sleep 1500ms
