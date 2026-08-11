#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 07: Remote Skills — SRE Post-Mortem from GitHub
# ========================================================
# Demonstrates loading skills directly from a GitHub repository
# and using them to draft a post-mortem for a recent incident.
#
# Features showcased:
#   - GitHub URL skill loading (auto-clone + cache)
#   - add_skill with skill_name: to pick a specific skill from a repo
#   - Inline skill for custom output formatting
#   - Workspace analysis with SRE context
#
# Usage:
#   rv run ruby examples/07_skill_remote_sre.rb
#   rv run ruby examples/07_skill_remote_sre.rb ~/git/my-failing-app
#
# The SRE skills are fetched from:
#   https://github.com/gemini-cli-extensions/sre

require_relative 'rv/rv_init'

SRE_REPO = 'https://github.com/gemini-cli-extensions/sre'

workspace = ARGV[0] || File.expand_path('..', __dir__)

puts "#{Antigravity.emoji(:magnifying)} Antigravity Ruby SDK — Remote Skills: SRE Post-Mortem"
puts '=' * 60
puts

# --- Remote skill loading from GitHub ---

puts "#{Antigravity.emoji(:skill)} Loading SRE skills from GitHub..."
puts "  Source: #{SRE_REPO}"
puts

agent = Antigravity::Agent.new(
  workspace: workspace,
  system_instruction: "You are an SRE specialist reviewing the codebase at #{File.expand_path(workspace)}. " \
                      "Use the available tools to inspect the code, logs, error handling, and configuration."
)

# Load a specific skill from the remote SRE repo (skill_name: picks one)
puts "  Fetching postmortem-generator..."
agent.add_skill(SRE_REPO, skill_name: 'skills/postmortem-generator')

# Also load the investigation entrypoint skill
puts "  Fetching investigation-entrypoint..."
agent.add_skill(SRE_REPO, skill_name: 'skills/investigation-entrypoint')

# Add an inline skill for output formatting
agent.add_inline_skill(
  name: "postmortem-format",
  description: "Formats post-mortem output for terminal display",
  instructions: <<~SKILL
    Format the post-mortem with these sections using terminal-friendly markers:
    - Title: prefixed with 🔥
    - Timeline: each event prefixed with 🕐 and timestamp
    - Impact: prefixed with 💥
    - Root Cause: prefixed with 🔍
    - Action Items: each prefixed with ✅ and tagged [P0/P1/P2]
    - Lessons Learned: prefixed with 📝
  SKILL
)

# Show loaded skills
puts
puts "  Loaded #{agent.skills.size} skills:"
agent.skills.each do |s|
  type = s.path ? 'remote' : 'inline'
  puts "    #{Antigravity.emoji(:check)} #{s.name} (#{type}) — #{s.description[0, 55]}..."
end
puts

puts "#{Antigravity.emoji(:workspace)} Workspace: #{workspace}"
puts

# --- Connect and generate post-mortem ---
agent.connect!
puts

# Simulate a realistic incident scenario
question = <<~Q
  Use the postmortem-generator skill to draft a post-mortem for this scenario:

  **Incident**: The CI/CD pipeline for this Ruby SDK has been failing intermittently
  for the past 24 hours. Tests pass locally but fail in CI with timeout errors.
  The issue appears related to the WebSocket connection in the harness.

  Review the codebase (especially connection/ and the test files) using the
  investigation-entrypoint skill, then generate a post-mortem draft using the
  postmortem-format skill for output styling.

  Keep it concise — this is a draft, not the final document.
Q

puts "#{Antigravity.emoji(:prompt)} Post-mortem request submitted..."
puts
puts "\e[36m#{'─' * 60}\e[0m"

response = agent.ask(question, timeout: 120) do |chunk|
  print "\e[36m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[36m#{'─' * 60}\e[0m"
puts

# Show metadata
puts '--- Post-Mortem Metadata ---'
puts "  Model:        #{response.model_id}"
puts "  Tokens used:  #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:   #{response.tool_calls_count}"
puts "  Steps:        #{response.steps&.length || 0}"
puts "  Skills:       #{agent.skills.map(&:name).join(', ')}"
puts
puts "  Skills cache: ~/.antigravity/cache/ruby-sdk/skills/"
puts

agent.close!
puts "#{Antigravity.emoji(:success)} Done! Agent closed."
