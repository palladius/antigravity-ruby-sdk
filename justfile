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

# --- rv tasks (no gem install needed, like 'uv' for Python) ---

# Simple LLM chat — no workspace, fast
rv-chat:
    rv run ruby -Ilib examples/04_simple_llm_chat.rb

# Workspace analysis — indexes a directory, asks about it
rv-workspace DIR=".":
    rv run ruby -Ilib examples/05_workspace_analysis.rb {{DIR}}

# Run all rv examples
rv-examples: rv-chat rv-workspace
