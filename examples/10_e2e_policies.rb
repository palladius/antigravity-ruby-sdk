#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/antigravity'

# 1. Define a Declarative Policy
# We'll allow listing directories but confirm file creation
# and strictly deny arbitrary commands unless it's echo.
policy = Antigravity::Policy.define do
  deny_all
  allow :list_dir
  allow :run_command, when: cmd('echo')
  confirm :create_file, when: path('*.txt', '*.log')
  deny :run_command, when: cmd('rm', 'sudo')
end

# Set a global handler for confirmations (e.g., asking user in CLI)
policy.on_confirm do |ctx|
  puts "[POLICY] The agent wants to use #{ctx[:name]} with args: #{ctx[:args]}"
  print "[POLICY] Do you allow this? (y/n): "
  # For the example, we'll auto-approve if it contains 'auto_approve'
  # and deny otherwise.
  ctx[:args][:content]&.include?('auto_approve')
end

# 2. Attach Policy to an Agent
agent = Antigravity::Agent.new(policies: [policy], auto_logger: false)

# Setup dummy tools
agent.register_tool(:list_dir, description: "List directory contents") do |dir:|
  "Listing #{dir}"
end

agent.register_tool(:run_command, description: "Run shell command") do |command_line:|
  "Executing #{command_line}"
end

agent.register_tool(:create_file, description: "Create file") do |path:, content:|
  "Created #{path}"
end

# 3. See it in Action (Hooks will enforce the rules)
puts "\n--- Test 1: Allowed by default ---"
puts "Result: #{agent.hooks.run_pre_tool(:list_dir, dir: '.')}"

puts "\n--- Test 2: Specific Allow (echo) ---"
puts "Result: #{agent.hooks.run_pre_tool(:run_command, command_line: 'echo hello')}"

puts "\n--- Test 3: Specific Deny (rm) ---"
puts "Result: #{agent.hooks.run_pre_tool(:run_command, command_line: 'rm -rf /')}"

puts "\n--- Test 4: Confirm (handled by handler) ---"
puts "Result: #{agent.hooks.run_pre_tool(:create_file, path: 'test.txt', content: 'hello auto_approve')}"

puts "\n--- Test 5: Confirm (denied by handler) ---"
puts "Result: #{agent.hooks.run_pre_tool(:create_file, path: 'test.txt', content: 'malicious payload')}"

puts "\n--- Test 6: Default Deny (unmatched) ---"
puts "Result: #{agent.hooks.run_pre_tool(:lookup_secret, key: 'API_KEY')}"
