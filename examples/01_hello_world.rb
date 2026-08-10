# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "antigravity"

puts "🚀 Antigravity Ruby SDK — Hello World Example"
puts "==============================================="

# Uses sensible defaults (model: gemini-flash-latest)
agent = Antigravity::Agent.new do |a|
  a.system_instruction = "You are a helpful and concise Ruby AI assistant."
end

print "Assistant: "
final_msg = agent.ask("Write a 1-line poem about Ruby.") do |chunk|
  print chunk.content if chunk.content
end

puts "\n\n--- Turn Summary ---"
puts "Model: #{final_msg.model_id}"
puts "Full Content: #{final_msg.content.strip}"
