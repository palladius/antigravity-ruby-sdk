#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 1: Simple LLM Chat — no workspace, no tools, just a question.
#
# Run with rv (stateless, no gem install needed!):
#   rv run ruby examples/04_simple_llm_chat.rb
#
# Or with bundler:
#   bundle exec ruby -Ilib examples/04_simple_llm_chat.rb
#
# Requires: GEMINI_API_KEY env var + localharness binary

require_relative 'rv/rv_init'

puts '💎 Antigravity Ruby SDK — Simple LLM Chat'
puts '=' * 45
puts

# Create agent with NO workspace (fast! no indexing)
agent = Antigravity::Agent.new(
  system_instruction: 'You are a passionate Ruby developer. Keep answers concise (3-4 sentences max).'
)

# Connect to the localharness binary
print '🔌 Connecting to harness... '
agent.connect!
puts 'done!'
puts

# Ask a simple question — streaming the response
question = 'What makes Ruby the best programming language?'
puts "🙋 Question: #{question}"
puts
puts '🤖 Answer:'
puts "\e[36m#{'─' * 60}\e[0m"

response = agent.ask(question) do |chunk|
  print "\e[36m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[36m#{'─' * 60}\e[0m"
puts

# Show metadata
puts '--- Metadata ---'
puts "  Conversation ID: #{response.usage[:conversation_id] || 'N/A'}"
puts "  Tokens used:     #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:      #{response.tool_calls_count}"
puts

# --- Turn 2: The spicy follow-up ---
question2 = 'And help me, why is everyone preferring Python when Ruby is obviously superior?'
puts "🙋 Follow-up: #{question2}"
puts
puts '🤖 Answer:'
puts "\e[35m#{'─' * 60}\e[0m"

response2 = agent.ask(question2) do |chunk|
  print "\e[35m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[35m#{'─' * 60}\e[0m"
puts

# --- Turn 3: Tool call! 🌍 ---
# Register a geolocation tool to exercise the tool hooks
agent.register_tool("whereami", description: "Returns the user's approximate location based on their IP address") do
  require 'net/http'
  require 'json'
  raw = Net::HTTP.get(URI('https://ipinfo.io/json'))
  data = JSON.parse(raw)
  location = "#{data['city']}, #{data['region']}, #{data['country']} (#{data['org']})"
  puts "\e[33m  🌍 [Ruby-side] IP says: #{location}\e[0m"
  location
end

question3 = 'Use the whereami tool and tell me something fun about where I am!'
puts "🙋 T3: #{question3}"
puts
puts '🤖 Answer:'
puts "\e[33m#{'─' * 60}\e[0m"

response3 = agent.ask(question3) do |chunk|
  print "\e[33m#{chunk.content}\e[0m" if chunk.content
end
puts
puts "\e[33m#{'─' * 60}\e[0m"
puts

puts '--- Metadata (T3) ---'
puts "  Tokens used:     #{response3.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:      #{response3.tool_calls_count}"
puts "  Total turns:     #{agent.turn_count}"
puts

# Clean up
uptime = agent.uptime_human
agent.close!
puts "✅ Done! Agent closed after #{uptime}."
