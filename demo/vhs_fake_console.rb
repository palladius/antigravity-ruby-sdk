#!/usr/bin/env ruby
# frozen_string_literal: true

# 🎬 VHS Demo Script — Simulates the Richard console for recording.
# The chat/agent parts are fake, but Ruby eval results use REAL pp output.
#
# Usage: ruby demo/vhs_fake_console.rb

require 'pp'
require 'stringio'

# ANSI styles (matching real console.rb)
DIM       = "\e[2m"
BOLD_CYAN = "\e[1;36m"
THINKING  = "\e[2;3m"
TOOL      = "\e[0;33m"
RED       = "\e[31m"
BOLD_RED  = "\e[1;31m"
GREEN     = "\e[32m"
MAGENTA   = "\e[1;35m"
WHITE     = "\e[1;37m"
RESET     = "\e[0m"
PROMPT    = "#{RED}♦#{RESET}agy> "
IRB_PROMPT = "#{RED}💎#{RESET}irb> "

def type_effect(text, delay: 0.04)
  text.each_char { |c| print c; $stdout.flush; sleep(delay) }
end

def fake_thinking(text, delay: 0.02)
  print "  #{THINKING}🤔 "
  type_effect(text, delay: delay)
  puts RESET
end

def fake_response(text, delay: 0.02)
  text.each_char { |c| print "#{BOLD_CYAN}#{c}#{RESET}"; $stdout.flush; sleep(delay) }
  puts
end

def fake_metadata(tok:, prompt_tok:, cand_tok:, tools: 0, elapsed:)
  tool_str = tools > 0 ? " | 💾 #{tools} tools" : ""
  puts "#{DIM}  🪙 #{tok} tok (#{prompt_tok}->#{cand_tok})#{tool_str} | ⏱️ #{elapsed}s#{RESET}"
  puts
end

# Pretty-print a real Ruby object with => prefix, indented
def irb_pp(obj)
  out = PP.pp(obj, StringIO.new).string.strip
  lines = out.lines
  puts "  #{BOLD_CYAN}=> #{lines.first.strip}#{RESET}"
  lines[1..].each { |l| puts "  #{BOLD_CYAN}   #{l.rstrip}#{RESET}" }
  puts
end

def prompt_line = (print PROMPT; $stdout.flush)
def irb_line    = (print IRB_PROMPT; $stdout.flush)

WS = '/Users/ricc/git/antigravity-ruby-sdk'

# ── Real data for the demo ───────────────────────────────────
CONFIG = {
  version: '0.6.0',
  workspace: WS,
  policy: :console,
  model: 'gemini-2.5-pro',
  thinking: :collapsed,
  turn_count: 2,
  conv_id: 'a3f7c2b1',
  api_key: 'AIza****p4Ys',
  ruby: RUBY_VERSION,
  pid: Process.pid,
}.freeze

SAFE_CMDS = %i[cd date echo hostname ls md5 pwd uname wc which whoami].freeze
CATASTROPHIC_CMDS = ['dd if=/dev/urandom', 'dd if=/dev/zero', '> /dev/sd',
                     'halt', 'mkfs', 'reboot', 'rm -rf /', 'shutdown'].freeze
DESTRUCTIVE_GIT = ['git push --force', 'git push -f', 'git reset --hard',
                   'git clean -fdx', 'git stash drop'].freeze

# ═══════════════════════════════════════════════════════════════
# ACT 1: Banner
# ═══════════════════════════════════════════════════════════════
puts
puts "#{MAGENTA}💎 Richard v0.6.0#{RESET} #{DIM}(Antigravity Console)#{RESET}"
puts "#{DIM}   Type a question, or /help for commands.#{RESET}"
puts "#{DIM}   🤔 #{THINKING}Thinking#{RESET} #{DIM}|#{RESET} 💬 #{BOLD_CYAN}Response#{RESET} #{DIM}|#{RESET} 💾 #{TOOL}Tools#{RESET}"
puts "#{DIM}   Use Ctrl-O to expand thinking and tool execution#{RESET}"
puts
print "#{DIM}🔌 Connecting to harness...#{RESET} "
sleep(0.8)
puts "#{GREEN}connected!#{RESET} #{DIM}(a3f7c2b1) 🛡️ policy:console#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# ACT 2: Quick chat
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("What Ruby version am I running?")
puts
sleep(0.3)
fake_thinking("Let me check the system...")
sleep(0.2)
fake_response("You're running Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}. 💎")
fake_metadata(tok: 215, prompt_tok: 98, cand_tok: 22, elapsed: 0.8)

# ═══════════════════════════════════════════════════════════════
# ACT 3: Shell + Ruby eval
# ═══════════════════════════════════════════════════════════════
sleep(0.4)
prompt_line
type_effect("! git branch --show-current")
puts
sleep(0.2)
puts "  #{TOOL}⚡ git branch --show-current#{RESET}"
puts "  feat/t001-thinking-console"
puts

sleep(0.4)
prompt_line
type_effect("r! Antigravity::VERSION")
puts
sleep(0.2)
puts "  #{TOOL}💎 Antigravity::VERSION#{RESET}"
puts "  #{BOLD_CYAN}=> \"0.6.0\"#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# ACT 4: /irb — THE MATRIX 💊
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("/irb")
puts
sleep(0.3)
puts "#{BOLD_RED}  💊 So you chose the RED pill, Neo!#{RESET}"
puts "#{DIM}  💎 Type 'exit' or Ctrl-D to return to Richard.#{RESET}"
puts "#{DIM}  💎 Type @irb_help for available objects.#{RESET}"
sleep(0.5)

# ── IRB: Full config (real pp!) ──────────────────────────────
irb_line
type_effect("config")
puts
sleep(0.3)
irb_pp(CONFIG)
sleep(0.5)

# ── IRB: Ruby power — .select ───────────────────────────────
irb_line
type_effect("config.select { |k,_| [:version, :workspace, :model].include?(k) }")
puts
sleep(0.3)
irb_pp(CONFIG.select { |k,_| [:version, :workspace, :model].include?(k) })
sleep(0.4)

# ── IRB: Policy — SAFE_CMDS ─────────────────────────────────
irb_line
type_effect("Policy::SAFE_CMDS")
puts
sleep(0.2)
irb_pp(SAFE_CMDS)
sleep(0.3)

# ── IRB: Policy — CATASTROPHIC (scary!) ──────────────────────
irb_line
type_effect("Policy::CATASTROPHIC_CMDS")
puts
sleep(0.2)
irb_pp(CATASTROPHIC_CMDS)
sleep(0.3)

# ── IRB: Policy — DESTRUCTIVE_GIT ────────────────────────────
irb_line
type_effect("Policy::DESTRUCTIVE_GIT_CMDS")
puts
sleep(0.2)
irb_pp(DESTRUCTIVE_GIT)
sleep(0.4)

# ── IRB: Smart setters ──────────────────────────────────────
irb_line
type_effect("cd '~/git/sakura'")
puts
sleep(0.2)
puts "#{DIM}  📂 Workspace → /Users/ricc/git/sakura#{RESET}"
puts
sleep(0.3)

irb_line
type_effect("set_policy :turbo")
puts
sleep(0.2)
puts "#{DIM}  🛡️ Policy → :turbo#{RESET}"
puts
sleep(0.3)

# ── IRB: Verify with .select ────────────────────────────────
irb_line
type_effect("config.select { |k,_| [:workspace, :policy].include?(k) }")
puts
sleep(0.2)
irb_pp({workspace: '/Users/ricc/git/sakura', policy: :turbo})
sleep(0.3)

# ── IRB: Exit Matrix ────────────────────────────────────────
irb_line
type_effect("exit")
puts
sleep(0.3)
puts "#{WHITE}  Welcome... to the real world, Neo. 🕶️#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# FINALE
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("/quit")
puts
sleep(0.3)
puts "#{DIM}👋 Console closed.#{RESET}"
puts
