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

# Clean up
agent.close!
puts '✅ Done! Agent closed.'
