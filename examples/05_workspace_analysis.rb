#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 2: Workspace Analysis — ask the agent about a local directory.
#
# Run with rv (stateless, no gem install needed!):
#   rv run ruby examples/05_workspace_analysis.rb
#   rv run ruby examples/05_workspace_analysis.rb /path/to/project
#
# Or with bundler:
#   bundle exec ruby -Ilib examples/05_workspace_analysis.rb
#
# Requires: GEMINI_API_KEY env var + localharness binary
#
# NOTE: Setting a workspace causes the harness to index the directory.
# The agent can then use built-in tools (list_dir, view_file) to explore it.
# This is slower than a simple chat but enables codebase-aware responses.

require_relative 'rv/rv_init'

# Use CLI arg or default to current SDK directory
workspace = ARGV[0] || File.expand_path('..', __dir__)

puts '🔍 Antigravity Ruby SDK — Workspace Analysis'
puts '=' * 48
puts
puts "📂 Workspace: #{workspace}"
puts

# Create agent WITH workspace — harness will index it
agent = Antigravity::Agent.new(
  workspace: workspace,
  system_instruction: 'You are a senior code reviewer with access to the workspace filesystem. ' \
                      'Use the available tools (list_dir, view_file) to explore the codebase. ' \
                      'Focus on architecture, tech stack, and purpose. 5 sentences max.'
)

# Connect (will show hourglass indexing message)
agent.connect!
puts

# Ask about the codebase — streaming
question = "What's cool about this repo? What does it do and what tech stack does it use?"
puts "🙋 Question: #{question}"
puts
print '🤖 Answer: '

response = agent.ask(question, timeout: 60) do |chunk|
  print chunk.content if chunk.content
end
puts
puts

# Show metadata
puts '--- Metadata ---'
puts "  Tokens used:  #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:   #{response.tool_calls_count}"
puts "  Steps:        #{response.steps&.length || 0}"
puts

# Clean up
agent.close!
puts '✅ Done! Agent closed.'
