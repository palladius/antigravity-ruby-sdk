#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 06: Skills — Security Audit
# =====================================
# Demonstrates Agent Skills support:
#   - Local skill loaded at construction time
#   - Inline skill added at runtime
#   - Skills auto-wired to harness via skillsPaths
#
# Usage:
#   rv run ruby examples/06_skill_security_audit.rb [path_to_audit]
#
# Example:
#   just rv-skill-audit
#   just rv-skill-audit ~/git/my-app

require_relative 'rv/rv_init'

workspace = ARGV[0] || File.expand_path('..', __dir__)

puts "#{Antigravity.emoji(:magnifying)} Antigravity Ruby SDK — Skills: Security Audit"
puts '=' * 56
puts

# --- Skill loading demo ---

# 1. Local skill: bundled security-audit skill
local_skill_path = File.expand_path('../skills/security-audit', __dir__)

puts "#{Antigravity.emoji(:skill)} Loading skills..."

agent = Antigravity::Agent.new(
  skills: [local_skill_path],       # Local path in constructor
  workspace: workspace,
  system_instruction: "You are a security auditor with access to the workspace at #{File.expand_path(workspace)}. " \
                      "Use the available tools (list_dir, view_file, grep_search) to inspect files. " \
                      "Focus on security issues. Be concise: max 10 findings."
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

# --- Connect and audit ---
agent.connect!
puts

question = <<~Q
  Perform a quick security audit of this codebase. Check for:
  1. Hardcoded secrets or API keys
  2. Unsafe file operations or eval usage
  3. Dependency vulnerabilities (check Gemfile)
  4. Injection risks

  Use the security-audit skill checklist and severity-emoji formatting.
  Keep it to max 10 findings. End with a severity summary.
Q

puts "#{Antigravity.emoji(:prompt)} Audit question submitted..."
puts
puts "\e[36m#{'─' * 60}\e[0m"

response = agent.ask(question, timeout: 90) do |chunk|
  print "\e[36m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[36m#{'─' * 60}\e[0m"
puts

# Show metadata
puts '--- Audit Metadata ---'
puts "  Model:        #{response.model_id}"
puts "  Tokens used:  #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:   #{response.tool_calls_count}"
puts "  Steps:        #{response.steps&.length || 0}"
puts "  Skills:       #{agent.skills.map(&:name).join(', ')}"
puts
puts "  skillsPaths sent to harness:"
agent.skills.each do |s|
  puts "    #{s.path || '(inline)'}"
end
puts

agent.close!
puts "#{Antigravity.emoji(:success)} Done! Agent closed."
