# frozen_string_literal: true

# Shared rv initialization for all examples.
# Handles gem resolution via bundler/inline — stateless, no `gem install` needed.
#
# Usage in examples:
#   require_relative 'rv/rv_init'
#
# Or standalone diagnostics:
#   rv run ruby -Ilib -Iexamples examples/rv/rv_init.rb
#   rv run ruby -Ilib -Iexamples examples/rv/rv_init.rb --verbose
#
# This file will grow as the SDK adds more runtime dependencies.

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'websocket', '~> 1.2'
  gem 'dotenv', '~> 3.0'
  # Future deps go here:
  # gem 'google-protobuf', '~> 4.0'  # Phase 4: proper protobuf
end

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
require 'antigravity'

# Run full diagnostics when invoked directly
if __FILE__ == $PROGRAM_NAME
  verbose = ARGV.include?('--verbose') || ARGV.include?('-v')
  Antigravity::Diagnostics.run!(verbose: verbose)
end
