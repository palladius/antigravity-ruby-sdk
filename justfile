# List available just tasks
default:
    @just -l

# Run unit tests only (fast, no harness needed)
test:
    bundle exec rspec --tag '~integration' spec/

# Run integration tests (requires localharness + GEMINI_API_KEY)
integration:
    bundle exec rspec --tag integration spec/

# Run ALL tests (unit + integration)
all-tests:
    bundle exec rspec spec/

# Run all example scripts
examples:
    bundle exec ruby -Ilib examples/01_hello_world.rb
    bundle exec ruby -Ilib examples/02_e2e_advanced_agent.rb
    bundle exec ruby -Ilib examples/03_e2e_safety_and_sidecar.rb

# Build the gem package into pkg/
build:
    bundle exec rake build

# Push gem package to RubyGems.org
release:
    bundle exec rake release

# Check if localharness binary is available
harness-check:
    bundle exec rake harness:check

# Download localharness binary from PyPI (⏳ ~50MB)
harness-fetch:
    bundle exec rake harness:fetch

# Force re-download localharness binary
harness-update:
    bundle exec rake harness:update

# --- rv tasks (stateless, no gem install needed — like `uv run`) ---

# Simple LLM chat — no workspace, fast
rv-chat:
    rv run ruby examples/04_simple_llm_chat.rb

# Workspace analysis — indexes a directory, asks about it
rv-workspace DIR=".":
    rv run ruby examples/05_workspace_analysis.rb {{DIR}}

# Skills demo: security audit with local + inline skills
rv-skill-audit DIR=".":
    rv run ruby examples/06_skill_security_audit.rb {{DIR}}

# Remote skills demo: SRE post-mortem from GitHub
rv-skill-sre-postmortem DIR=".":
    rv run ruby examples/07_skill_sre_postmortem.rb {{DIR}}

# Telegram bot with skills + audio (requires TELEGRAM_BOT_TOKEN in .env)
rv-skill-telegram:
    rv run ruby examples/08_skill_telegram_bot.rb

# E2E test for telegram bot agent pipeline (no Telegram needed!)
rv-e2e-telegram:
    rv run ruby examples/08_e2e_telegram_bot.rb
# E2E test for telegram bot agent pipeline (no Telegram needed!) - DEBUG
rv-e2e-telegram-debug:
  ANTIGRAVITY_DEBUG=1 rv run ruby examples/08_e2e_telegram_bot.rb

# E2E test for nanobanana image generation pipeline
rv-e2e-nanobanana:
    rv run ruby examples/09_e2e_nanobanana.rb

# Run all rv examples (excludes telegram — it's a long-running daemon)
rv-examples: rv-chat rv-workspace rv-skill-audit rv-skill-sre-postmortem
