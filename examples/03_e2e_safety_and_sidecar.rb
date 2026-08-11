# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "antigravity"

puts "🛡️ Antigravity Ruby SDK — Configurable Guards & Sidecar Example"
puts "==================================================================="

# 1. Instantiate AuditLogger Sidecar
audit_logger = Antigravity::Sidecar::AuditLogger.new("log/safety_demo_audit.jsonl")

# 2. Instantiate opt-in Configurable Guards
file_guard = Antigravity::Guards::FileProtection.new(files: [".env", "Gemfile"])
secret_masker = Antigravity::Guards::SecretMasker.new

# 3. Build Agent and attach hooks & sidecar explicitly
agent = Antigravity::Agent.new do |a|
  a.system_instruction = "You are an agent equipped with opt-in FileProtection and SecretMasker guards."

  a.attach_sidecar(audit_logger)

  # Explicitly attach configurable guards
  a.before_tool_call(&file_guard)
  a.after_tool_call(&secret_masker)

  # Register tools
  a.register_tool("write_file", description: "Modifies file content") do |params|
    "Successfully modified #{params[:path]}"
  end

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

audit_logger.stop!

puts "\n\n📜 [Sidecar Audit Log Output] (log/safety_demo_audit.jsonl):"
if File.exist?("log/safety_demo_audit.jsonl")
  puts File.read("log/safety_demo_audit.jsonl")
end

puts "==================================================================="
puts "✅ Configurable Guards & Sidecar Example Completed Successfully!"
