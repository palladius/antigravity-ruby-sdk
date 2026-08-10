# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "antigravity"

puts "💎 Antigravity Ruby SDK — Advanced E2E Showcase"
puts "================================================"

# Define a declarative tool
class WeatherTool
  include Antigravity::Tool
  tool_name "get_weather"
  tool_description "Fetches live weather reports"
  param :location, type: :string, description: "City or region", required: true

  def call(location:)
    "☀️ 24°C in #{location}"
  end
end

# Build the Agent with reflective configuration
agent = Antigravity::Agent.new(model: "gemini-2.5-pro") do |a|
  a.system_instruction = "You are a smart SRE assistant capable of running tools and sidecars."

  # Register declarative and dynamic tools
  a.register_tool(WeatherTool.new)
  a.register_tool("fetch_metrics", description: "Fetch system CPU/Memory metrics") do |params|
    { cpu: "12%", memory: "1.4GB / 16GB" }
  end

  # Pre-hook: Audit prompt before sending
  a.before_prompt do |prompt_text|
    puts "🛡️ [Pre-Hook] Auditing prompt: '#{prompt_text}'"
  end

  # Post-hook: Telemetry after response
  a.after_response do |response|
    puts "\n📊 [Post-Hook] Response received! Tokens used: #{response.tokens.inspect}"
  end

  # Tool-hook: Sidecar audit on tool dispatch
  a.on_tool_call do |tool_name, params|
    puts "⚙️ [Tool-Hook / Sidecar Dispatch] Executing tool '#{tool_name}' with #{params.inspect}"
  end
end

# Prompt agent with live streaming
puts "\n💬 User: Tell me about get_weather in Milan and fetch metrics."
puts "--------------------------------------------------------"

final_message = agent.prompt("Check get_weather in Milan") do |chunk|
  print "💭 [Thought] #{chunk.thinking}\n" if chunk.thinking && !chunk.thinking.empty?
  print "🛠️ [Tool] Called #{chunk.tool_calls.inspect}\n" if chunk.tool_calls && !chunk.tool_calls.empty?
  print chunk.content if chunk.content
end

puts "\n\n✅ [E2E Completed Successfully]"
puts "Final Message Content: #{final_message.content}"
