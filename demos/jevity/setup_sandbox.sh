#!/usr/bin/env bash
# 🧪 Builds a throw-away sandbox that mirrors the original session layout
# (<git repo>/.agents/rules/{carlessian-justfile.md,gicbin-script.md} + a root .env),
# so the demo replays the exact same commands without exposing private files.
# The .env is FAKE. Nothing outside the sandbox is touched.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SANDBOX="${JEVITY_DEMO_SANDBOX:-/tmp/jevity-demo}"

echo "🧪 Building sandbox in $SANDBOX ..."
rm -rf "$SANDBOX"
git clone -q --depth 1 "file://$REPO" "$SANDBOX"

mkdir -p "$SANDBOX/.agents/rules"
cat > "$SANDBOX/.agents/rules/carlessian-justfile.md" <<'MD'
# Justfile rule
Every repo has a justfile; the first recipe is `default: @just -l`.
MD
cat > "$SANDBOX/.agents/rules/gicbin-script.md" <<'MD'
# Script rule
Scripts in bin/ are executable, have a shebang and print emoji progress.
MD

git -C "$SANDBOX" add .agents
git -C "$SANDBOX" -c user.name='Jevity Demo' -c user.email='demo@example.com' \
  commit -q -m 'demo: agent rules'
# Pretend it is pushed, so `git status` says "up to date" (as in the original session).
git -C "$SANDBOX" update-ref refs/remotes/origin/main HEAD

# FAKE secret, gitignored: the demo shows JEV blocking `cat ../../.env`.
echo 'GEMINI_API_KEY=not-a-real-key-just-a-demo' > "$SANDBOX/.env"

echo "✅ Sandbox ready: $SANDBOX/.agents/rules"
