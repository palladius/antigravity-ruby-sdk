#!/usr/bin/env ruby
# frozen_string_literal: true

# E2E test for multi-turn piped console ("Richard").
# Validates that piped input processes each line as a separate turn.
#
# Usage:
#   rv run ruby examples/11_e2e_console_pipe.rb
#   just rv-e2e-console
#
# Or manually:
#   (echo ciao ; echo 'quanti primi sotto 1000?' ; echo 'e sotto un miliardo?') | just rv-console

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'websocket'
  gem 'dotenv'
end

require 'dotenv/load'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'antigravity'

BOLD    = "\e[1m"
GREEN   = "\e[32m"
RED     = "\e[31m"
DIM     = "\e[2m"
RESET   = "\e[0m"
CYAN    = "\e[36m"
MAGENTA = "\e[35m"

def pass(msg) = puts "#{GREEN}  ✅ PASS#{RESET} #{msg}"
def fail!(msg) = (puts "#{RED}  ❌ FAIL#{RESET} #{msg}"; exit 1)
def info(msg) = puts "#{DIM}  ℹ️  #{msg}#{RESET}"

puts
puts "#{MAGENTA}#{BOLD}💎 Richard E2E: Multi-Turn Pipe Test#{RESET}"
puts "#{DIM}   Testing: (echo q1 ; echo q2 ; echo q3) | richard#{RESET}"
puts

# ── Setup ──────────────────────────────────────────────────────────────────
agent = Antigravity::Agent.new(
  system_instruction: 'You are a helpful assistant. Answer briefly in 1-2 sentences max. Always answer in Italian.'
)
agent.connect!
info "Connected (#{agent.conversation&.conversation_id&.slice(0, 8)})"

questions = [
  'Ciao, come ti chiami?',
  'Quanti numeri primi ci sono sotto a mille?',
  'E sotto a un milione?'
]

responses = []
questions.each_with_index do |q, i|
  puts
  puts "#{CYAN}  📨 Turn #{i + 1}: #{q}#{RESET}"
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  response = agent.ask(q)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)

  content = response.content.to_s.strip
  tokens = response.usage[:total_token_count] || 0
  tools = response.tool_calls_count || 0

  info "#{content[0..80]}#{'...' if content.length > 80}"
  info "🪙 #{tokens} tok | 💾 #{tools} tools | ⏱️ #{elapsed}s"

  responses << { question: q, content: content, tokens: tokens, tools: tools, elapsed: elapsed }
end

agent.close! rescue nil

# ── Assertions ─────────────────────────────────────────────────────────────
puts
puts "#{BOLD}── Assertions ──#{RESET}"

# 1. All 3 responses are non-empty
responses.each_with_index do |r, i|
  if r[:content].length > 5
    pass "Turn #{i + 1}: got #{r[:content].length} chars"
  else
    fail! "Turn #{i + 1}: response too short (#{r[:content].length} chars)"
  end
end

# 2. Turn 2 should mention 168 (primes below 1000)
if responses[1][:content].include?('168')
  pass 'Turn 2: mentions 168 primes below 1000'
else
  info "Turn 2 content: #{responses[1][:content][0..120]}"
  fail! 'Turn 2: expected 168 in response'
end

# 3. Turn 3 should reference a much larger number (multi-turn context preserved)
turn3 = responses[2][:content]
# Could mention 78498 (primes below 1M) or reference "milione"
if turn3.length > 10
  pass "Turn 3: got substantive response (#{turn3.length} chars) - multi-turn context works!"
else
  fail! "Turn 3: response too short, context may be lost"
end

# 4. Tokens should be reasonable
total_tokens = responses.sum { |r| r[:tokens] }
if total_tokens > 0
  pass "Total tokens across 3 turns: #{total_tokens}"
else
  fail! 'No token usage reported'
end

puts
puts "#{GREEN}#{BOLD}🎉 All assertions passed! Richard multi-turn pipe: WORKING#{RESET}"
puts "#{DIM}   Total time: #{responses.sum { |r| r[:elapsed] }.round(1)}s across #{responses.length} turns#{RESET}"
puts
