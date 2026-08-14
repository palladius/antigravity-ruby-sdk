#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 05: Hooks & Tools E2E — custom tool, lifecycle hooks, multi-turn, post-tool hook.
# Exercises: whereami tool, tool_call/tool_result hooks, 🪝 lifecycle logger, multi-turn context.
#
# Run with rv (stateless, no gem install needed!):
#   rv run ruby examples/05_hooks_tools_e2e.rb
#
# Or with bundler:
#   bundle exec ruby -Ilib examples/05_hooks_tools_e2e.rb
#
# Requires: GEMINI_API_KEY env var + localharness binary

require_relative 'rv/rv_init'

SEP = "\e[33m#{'─' * 60}\e[0m"

puts '💎 Antigravity Ruby SDK — Hooks & Tools E2E'
puts '=' * 47
puts

# Create agent with NO workspace (fast! no indexing)
agent = Antigravity::Agent.new(
  system_instruction: 'You are a passionate Ruby developer. Keep answers concise (3-4 sentences max).'
)

# Register a geolocation tool to exercise the tool hooks
agent.register_tool("whereami", description: "Returns the user's approximate location based on their IP address as JSON") do
  require 'net/http'
  require 'json'
  begin
    raw = Net::HTTP.get(URI('https://ipinfo.io/json'))
    data = JSON.parse(raw)
    #puts "\e[33m  🌍 [Ruby-side] Got #{raw.bytesize}B from ipinfo.io\e[0m"
    { status: 'success', response: data }.to_json
  rescue StandardError => e
    puts "\e[31m  💥 [Ruby-side] #{e.class}: #{e.message}\e[0m"
    { status: 'error', error: e.message }.to_json
  end
end

# Custom post-tool hook: pretty-print whereami results
agent.hooks.on(:tool_result) do |info|
  next unless info[:tool_name] == 'whereami'
  require 'json'
  data = JSON.parse(info[:result]) rescue nil
  next unless data&.dig('status') == 'success'
  r = data['response']
  puts "\e[33m  📍 #{r['ip']} (#{r['city']}, #{r['country']})\e[0m"
end

# Connect to the localharness binary
print '🔌 Connecting to harness... '
agent.connect!
puts 'done!'
puts

# --- Turn 1: Tool call! 🌍 ---
question = 'Use the whereami tool and tell me something fun about where I am!'
puts "🙋 Question: #{question}"
puts
puts '🤖 Answer:'
puts SEP

response = agent.ask(question) do |chunk|
  print "\e[33m#{chunk.content}\e[0m" if chunk.content
end
puts
puts SEP
puts

puts '--- Metadata ---'
puts "  Tokens used:     #{response.usage[:total_token_count] || 'N/A'}"
puts "  Tool calls:      #{response.tool_calls_count}"
puts "  Total turns:     #{agent.turn_count}"
puts

# --- Turn 2: Follow-up (no tool, just context from T1) ---
question2 = 'Now just tell me the country where I am, preceded by its flag emoji. One line only.'
puts "🙋 Follow-up: #{question2}"
puts
puts '🤖 Answer:'
puts SEP

response2 = agent.ask(question2) do |chunk|
  print "\e[36m#{chunk.content}\e[0m" if chunk.content
end
puts
puts SEP
puts

# --- Turn 3: Ruby love ---
question3 = 'What makes Ruby the best programming language?'
puts "🙋 T3: #{question3}"
puts
puts '🤖 Answer:'
puts SEP

response3 = agent.ask(question3) do |chunk|
  print "\e[35m#{chunk.content}\e[0m" if chunk.content
end
puts
puts SEP
puts

# --- Turn 4: The spicy follow-up ---
question4 = 'And help me, why is everyone preferring Python when Ruby is obviously superior?'
puts "🙋 T4: #{question4}"
puts
puts '🤖 Answer:'
puts SEP

response4 = agent.ask(question4) do |chunk|
  print "\e[34m#{chunk.content}\e[0m" if chunk.content
end
puts
puts SEP
puts


# === E2E Assertions ===
puts '🧪 E2E Assertions:'
failures = []

{ 'T1 (whereami)' => response, 'T2 (flag emoji)' => response2,
  'T3 (Ruby love)' => response3, 'T4 (Python vs Ruby)' => response4 }.each do |label, resp|
  content = resp.respond_to?(:content) ? resp.content.to_s : ''
  if content.empty?
    failures << label
    puts "  ❌ #{label}: 0B response — FAIL"
  else
    puts "  ✅ #{label}: #{content.bytesize}B — OK"
  end
end

# T1 must have tool calls
if response.tool_calls_count < 1
  failures << 'T1 tool_calls_count'
  puts '  ❌ T1 tool_calls_count: expected >= 1 — FAIL'
else
  puts "  ✅ T1 tool_calls_count: #{response.tool_calls_count} — OK"
end

# Turn count
if agent.turn_count != 4
  failures << 'turn_count'
  puts "  ❌ turn_count: expected 4, got #{agent.turn_count} — FAIL"
else
  puts '  ✅ turn_count: 4 — OK'
end

puts

# Clean up
uptime = agent.uptime_human
agent.close!

if failures.empty?
  puts "✅ Done! All assertions passed. Agent closed after #{uptime}."
else
  puts "❌ FAILED: #{failures.join(', ')}. Agent closed after #{uptime}."
  exit 1
end
