# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "antigravity"

puts "🛡️ Antigravity Ruby SDK — Custom Safety Hooks & Sidecar Example"
puts "==================================================================="

# --- Educational Sample Hook 1: Pre-Tool File Guard ---
# Illustrates how developers can create custom policy guards by returning :allow or :deny
class ProtectedFilesGuard
  PROTECTED_PATTERNS = [/\.env(\..*)?$/i, /Gemfile(\.lock)?$/i].freeze

  def call(tool_name, params)
    path = params[:path] || params["path"]
    return :allow unless path

    if PROTECTED_PATTERNS.any? { |pattern| path =~ pattern }
      { status: :deny, reason: "Security Policy: Edits to '#{path}' are restricted and require user approval." }
    else
      :allow
    end
  end

  def to_proc
    method(:call).to_proc
  end
end

# --- Educational Sample Hook 2: Post-Tool Secret Masker ---
# Illustrates how developers can sanitize or redact sensitive data from tool outputs
class SecretMasker
  SECRET_PATTERNS = [/(AIzaSy[A-Za-z0-9_-]{25,45})/].freeze

  def call(_tool_name, _params, result)
    return result unless result.is_a?(String)

    sanitized = result.dup
    SECRET_PATTERNS.each { |pattern| sanitized.gsub!(pattern, "[REDACTED_SECRET]") }
    sanitized
  end

  def to_proc
    method(:call).to_proc
  end
end

# --- Scenario Execution ---

audit_logger = Antigravity::Sidecar::AuditLogger.new("log/safety_demo_audit.jsonl")

agent = Antigravity::Agent.new do |a|
  a.system_instruction = "You are an agent with custom security policy hooks."

  # Attach sidecar for async background log streaming
  a.attach_sidecar(audit_logger)

  # Attach custom pre/post tool hooks
  a.before_tool_call(&ProtectedFilesGuard.new)
  a.after_tool_call(&SecretMasker.new)

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
puts "✅ Custom Safety Hooks & Sidecar Example Completed Successfully!"
