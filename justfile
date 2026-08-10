# List available just tasks
default:
    @just -l

# Run all RSpec tests
test:
    bundle exec rake spec

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
