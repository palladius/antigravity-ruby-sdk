#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 06: Security Audit with Skills
# =======================================
# Uses the bundled security-audit skill to analyze a Ruby codebase.
# Demonstrates: skills loading (local + inline), workspace analysis, structured output.
#
# Usage:
#   rv run ruby examples/06_security_audit.rb [path_to_audit]
#
# Example:
#   rv run ruby examples/06_security_audit.rb .
#   rv run ruby examples/06_security_audit.rb ~/git/my-app

require_relative "../lib/antigravity"

workspace = ARGV[0] || "."
puts "#{Antigravity.emoji(:magnifying)} Antigravity Ruby SDK -- Security Audit"
puts "=" * 56
puts

# --- Skill loading demo ---

# 1. Local skill: bundled security-audit skill
local_skill_path = File.expand_path("../skills/security-audit", __dir__)

# 2. Inline skill: custom output format (no file needed!)
#    This shows progressive disclosure: define a skill on the fly.

puts "#{Antigravity.emoji(:skill)} Loading skills..."

agent = Antigravity::Agent.new(
  model: "gemini-3.6-flash",
  skills: [local_skill_path],       # P1: local path in constructor
  workspace: workspace
)

# Add an inline skill at runtime (P1: progressive disclosure)
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
  type = s.path ? "local" : "inline"
  puts "    #{Antigravity.emoji(:check)} #{s.name} (#{type}) — #{s.description[0, 60]}"
end
puts

# --- Connect and audit ---
puts "#{Antigravity.emoji(:workspace)} Workspace: #{workspace}"
puts "#{Antigravity.emoji(:logger)} Logging to log/antigravity.jsonl"

question = <<~Q
  Perform a security audit of this codebase. Focus on:
  1. Hardcoded secrets or API keys
  2. Unsafe file operations
  3. Dependency vulnerabilities
  4. Injection risks (eval, system, exec)
  5. Network security (HTTP vs HTTPS, TLS)

  Use the security-audit skill checklist. Report findings with severity-emoji formatting.
  End with a summary: total findings by severity level.
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

# Show skills paths that were sent to harness
puts "  skillsPaths sent to harness:"
agent.skills.each do |s|
  puts "    #{s.path || '(inline)'}"
end
