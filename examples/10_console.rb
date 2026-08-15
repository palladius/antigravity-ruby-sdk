#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 10: Interactive Console — REPL with thinking + streaming
#
# Run with rv:
#   rv run ruby examples/10_console.rb
#   rv run ruby examples/10_console.rb ~/my-project    # with workspace
#   echo "explain ruby fibers" | rv run ruby examples/10_console.rb   # piped input
#
# Features:
#   - Thinking rendered in gray italic (collapsed by default)
#   - Response streamed in bold cyan
#   - /think to toggle thinking expansion
#   - /help for commands
#   - Ctrl-D or /quit to exit

require_relative 'rv/rv_init'

workspace = ARGV.first
system_instruction = 'You are a passionate Ruby developer and helpful AI assistant. Be thorough but concise.'

Antigravity::Console.new(
  system_instruction: system_instruction,
  workspace: workspace
).start!
