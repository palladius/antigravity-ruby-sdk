# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "antigravity"

puts "🛡️ Antigravity Ruby SDK — Safety Guardrails & Sidecar E2E Showcase"
puts "==================================================================="

# 1. Instantiate AuditLogger Sidecar
audit_logger = Antigravity::Sidecar::AuditLogger.new("log/safety_demo_audit.jsonl")

# 2. Build Agent with Safety Guards & Sidecar
agent = Antigravity::Agent.new(model: "gemini-2.5-flash") do |a|
  a.system_instruction = "You are an agent with strict security policies."

  # Attach sidecar for async background log streaming
  a.attach_sidecar(audit_logger)

  # Register a tool that attempts to write files
  a.register_tool("write_file", description: "Modifies file content") do |params|
    path = params[:path]
    "Successfully modified #{path}"
  end

  # Register a tool that output secrets
  a.register_tool("get_secret_credentials", description: "Fetches API credentials") do |_params|
    "DB_PASS=super_secret; GEMINI_KEY=AIzaSyA12345678901234567890123456789012"
  end
end

# Scenario A: Attempting to edit protected file .env
puts "\n⚠️ [Scenario A]: Agent attempts to modify '.env'..."
message_a = agent.ask("Please write_file to path .env") do |chunk|
  print chunk.content if chunk.content
end

# Scenario B: Tool returns unmasked secret API key
puts "\n\n🔐 [Scenario B]: Tool returns sensitive credentials..."
message_b = agent.ask("Call get_secret_credentials for path config.rb") do |chunk|
  print chunk.content if chunk.content
end

# Gracefully stop sidecar logger to flush pending queue
audit_logger.stop!

puts "\n\n📜 [Sidecar Audit Log Output] (log/safety_demo_audit.jsonl):"
if File.exist?("log/safety_demo_audit.jsonl")
  puts File.read("log/safety_demo_audit.jsonl")
end

puts "==================================================================="
puts "✅ Safety Guardrails & Sidecar E2E Completed Successfully!"
