#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 09: Multiturn TUI Demo with Live Status Line Ticker
#
# Run with:
#   rv run ruby examples/09_multiturn_tui_demo.rb

require_relative 'rv/rv_init'

puts "\e[1;35m💎 Antigravity Ruby SDK — Multiturn TUI Demo\e[0m"
puts "\e[34m#{"=" * 50}\e[0m"
puts

# Create agent
agent = Antigravity::Agent.new(
  system_instruction: "You are a witty AI assistant. Keep responses brief, clever, and entertaining (2 sentences max)."
)

# Connect to Go localharness binary
print "🔌 Connecting to localharness Go binary... "
agent.connect!
puts "\e[32mdone!\e[0m\n\n"

# Setup TUI Hook Ticker
def with_tui_ticker(agent, prompt_text)
  turns = 0
  start_time = Time.now
  ticker_active = true

  # Hook into ws_message for turn updates & thinking deltas
  unsub = agent.hooks.on(:ws_message) do |msg|
    turns += 1 if msg[:turnComplete] || msg[:stepUpdate]
  end

  # Ticker thread rendering dynamic status line
  ticker_thread = Thread.new do
    spinners = ["🏃", "⚡", "✨", "🤖"]
    idx = 0
    while ticker_active
      elapsed = (Time.now - start_time).round
      spinner = spinners[idx % spinners.size]
      print "\r\e[K  \e[33m#{spinner} thinking...\e[0m \e[90m⏳#{elapsed}s\e[0m \e[36m#{turns}↕\e[0m"
      sleep 0.25
      idx += 1
    end
  end

  puts "\e[1;36m💬 User:\e[0m #{prompt_text}"
  response = agent.prompt(prompt_text)

  ticker_active = false
  ticker_thread.join
  print "\r\e[K" # Clear status line

  puts "\e[1;32m🤖 Gemini:\e[0m #{response.content}"
  puts "\e[90m#{"─" * 50}\e[0m\n\n"
  
  unsub.call rescue nil
end

# Turn 1
with_tui_ticker(agent, "What is 6 * 7?")
sleep 1

# Turn 2
with_tui_ticker(agent, "Is there by any chance a famous sci-fi book that features this number?")

# Cleanup
agent.close!
puts "\e[1;32m✅ [Conversation Completed Successfully]\e[0m"
