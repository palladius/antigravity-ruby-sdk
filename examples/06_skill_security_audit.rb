#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 06: Skills — Code Quality Review
# ==========================================
# Demonstrates Agent Skills support:
#   - Local skill loaded at construction time
#   - Inline skill added at runtime
#   - Skills auto-wired to harness via skillsPaths
#
# Usage:
#   rv run ruby examples/06_skill_security_audit.rb [path_to_review]
#
# Example:
#   just rv-skill-audit
#   just rv-skill-audit ~/git/my-app

require_relative 'rv/rv_init'

workspace = ARGV[0] || File.expand_path('..', __dir__)

puts "#{Antigravity.emoji(:magnifying)} Antigravity Ruby SDK — Skills: Code Quality Review"
puts '=' * 56
puts

# --- Skill loading demo ---

# 1. Local skill: bundled code-quality-review skill
local_skill_path = File.expand_path('../skills/code-quality-review', __dir__)

puts "#{Antigravity.emoji(:skill)} Loading skills..."

agent = Antigravity::Agent.new(
  skills: [local_skill_path],       # Local path in constructor
  workspace: workspace,
  system_instruction: "You are a senior Ruby engineer reviewing the codebase at #{File.expand_path(workspace)}. " \
                      "Use the available tools (list_dir, view_file, grep_search) to inspect source files. " \
                      "Focus on code quality, best practices, and potential improvements. Be concise."
)

# 2. Add an inline skill at runtime (progressive disclosure)
agent.add_inline_skill(
  name: "severity-emoji",
  description: "Maps severity levels to emoji for terminal output",
  instructions: <<~SKILL
    When reporting findings, use these emoji prefixes:
    - CRITICAL: 🚨
    - HIGH: 🔴
    - MEDIUM: 🟡
    - LOW: 🔵
    - PASSED: ✅

    Format each finding as:
    [emoji] [SEVERITY] file:line — description
  SKILL
)

# Show loaded skills
puts "  Loaded #{agent.skills.size} skills:"
agent.skills.each do |s|
  type = s.path ? 'local' : 'inline'
  puts "    #{Antigravity.emoji(:check)} #{s.name} (#{type}) — #{s.description[0, 60]}"
end
puts

puts "#{Antigravity.emoji(:workspace)} Workspace: #{workspace}"
puts

# --- Connect and review ---
agent.before_tool_call do |tool, args|
  puts "\n🛠️ [Tool] #{tool} #{args.inspect}"
end

agent.connect!
puts

question = "Use the code-quality-review skill to inspect the Ruby source code files in #{File.expand_path(workspace)} for code quality, Ruby idioms, and best practices. Apply the severity-emoji skill for output formatting. Max 10 findings."

puts "#{Antigravity.emoji(:prompt)} Review question submitted..."
puts
puts "\e[36m#{'─' * 60}\e[0m"

response = agent.ask(question, timeout: 90) do |chunk|
  print "\e[36m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[36m#{'─' * 60}\e[0m"
puts

# Show metadata
puts '--- Review Metadata ---'
puts "  Model:        #{response.model_id}"
puts "  Tokens used:  #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:   #{response.tool_calls_count}"
puts "  Steps:        #{response.steps&.length || 0}"
puts "  Skills:       #{agent.skills.map(&:name).join(', ')}"
puts

agent.close!
puts "#{Antigravity.emoji(:success)} Done! Agent closed."
