#!/usr/bin/env ruby
# frozen_string_literal: true

# 🎬 VHS FAKE Demo Script — Simulates the Richard console for recording.
# ⚠️  This is a SIMULATED demo. For the real thing, use: vhs demo/richard_real.tape
#
# Showcases: chat, ! cmd, r! eval, /irb (Matrix mode),
# smart setters (cd, set_policy), config introspection.
#
# Usage: ruby demo/vhs_fake_console.rb

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

def prompt_line
  print PROMPT
  $stdout.flush
end

def irb_line
  print IRB_PROMPT
  $stdout.flush
end

WS = '/Users/ricc/git/antigravity-ruby-sdk-t001'

# ═══════════════════════════════════════════════════════════════
# ACT 1: Disclaimer + Banner
# ═══════════════════════════════════════════════════════════════
puts "#{DIM}[This is a simulated demo. Commands are scripted for demonstration purposes.]#{RESET}"
puts "#{DIM}[For a real session, run: vhs demo/richard_real.tape]#{RESET}"
puts
puts "#{MAGENTA}💎 Richard v0.6.0#{RESET} #{DIM}(Antigravity Console)#{RESET}"
puts "#{DIM}   Type a question, or /help for commands.#{RESET}"
puts "#{DIM}   🤔 #{THINKING}Thinking#{RESET} #{DIM}|#{RESET} 💬 #{BOLD_CYAN}Response#{RESET} #{DIM}|#{RESET} 💾 #{TOOL}Tools#{RESET}"
puts "#{DIM}   Use Ctrl-O to expand thinking and tool execution#{RESET}"
puts
print "#{DIM}🔌 Connecting to harness...#{RESET} "
sleep(1.0)
puts "#{GREEN}connected!#{RESET} #{DIM}(a3f7c2b1) 🛡️ policy:console#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# ACT 2: Greeting
# ═══════════════════════════════════════════════════════════════
sleep(0.8)
prompt_line
type_effect("Ciao! Come stai? 🇮🇹")
puts
sleep(0.4)
fake_thinking("Un saluto italiano! Rispondiamo con calore...")
sleep(0.2)
fake_response("Ciao Riccardo! 🇮🇹 Sto benissimo, grazie!")
fake_response("Sono Richard, la tua console Antigravity. Come posso aiutarti? 🎉")
fake_metadata(tok: 342, prompt_tok: 128, cand_tok: 45, elapsed: 1.2)

# ═══════════════════════════════════════════════════════════════
# ACT 3: Shell exec
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("! pwd")
puts
sleep(0.2)
puts "  #{TOOL}⚡ pwd#{RESET}"
puts WS
puts

# ═══════════════════════════════════════════════════════════════
# ACT 4: Ruby eval
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("r! Antigravity::VERSION")
puts
sleep(0.2)
puts "  #{TOOL}💎 Antigravity::VERSION#{RESET}"
puts "  #{BOLD_CYAN}=> \"0.6.0\"#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# ACT 5: /irb — THE MATRIX 💊
# ═══════════════════════════════════════════════════════════════
sleep(0.8)
prompt_line
type_effect("/irb")
puts
sleep(0.3)
puts "#{BOLD_RED}  💊 So you chose the RED pill, Neo!#{RESET}"
puts "#{DIM}  💎 Type 'exit' or Ctrl-D to return to Richard.#{RESET}"
puts "#{DIM}  💎 Type @irb_help for available objects.#{RESET}"
sleep(0.5)

# IRB: help
irb_line
type_effect("help")
puts
sleep(0.3)
puts
puts "  #{MAGENTA}💎 Richard IRB — Available Objects#{RESET}"
puts
puts "  \e[1m📦 Instance Variables\e[0m"
puts "    @agent             Antigravity::Agent instance"
puts "    @workspace         Current working directory"
puts "    @policy            Policy preset symbol"
puts "    @model             Model name"
puts
puts "  \e[1m🔧 Methods (Smart Setters)\e[0m"
puts "    config             Full session state"
puts "    cd '/path'         Change workspace"
puts "    set_policy :turbo  Change safety policy"
puts "    set_model 'name'   Change model"
puts
sleep(0.5)

# IRB: config
irb_line
type_effect("config")
puts
sleep(0.2)
puts "  #{BOLD_CYAN}=> {version: \"0.6.0\", workspace: \"#{WS}\",#{RESET}"
puts "  #{BOLD_CYAN}    policy: :console, model: \"default\",#{RESET}"
puts "  #{BOLD_CYAN}    api_key: \"AIza****p4Ys\", ruby: \"3.4.5\", pid: 77555}#{RESET}"
puts
sleep(0.5)

# IRB: cd
irb_line
type_effect("cd '~/git/sakura'")
puts
sleep(0.2)
puts "#{DIM}  📂 Workspace → /Users/ricc/git/sakura#{RESET}"
puts
sleep(0.4)

# IRB: set_policy
irb_line
type_effect("set_policy :turbo")
puts
sleep(0.2)
puts "#{DIM}  🛡️ Policy → :turbo#{RESET}"
puts
sleep(0.4)

# IRB: verify config changed
irb_line
type_effect("[@workspace, @policy]")
puts
sleep(0.2)
puts "  #{BOLD_CYAN}=> [\"/Users/ricc/git/sakura\", :turbo]#{RESET}"
puts
sleep(0.4)

# IRB: cd back
irb_line
type_effect("cd '#{WS}'")
puts
sleep(0.1)
puts "#{DIM}  📂 Workspace → #{WS}#{RESET}"
puts
sleep(0.2)
irb_line
type_effect("set_policy :console")
puts
sleep(0.1)
puts "#{DIM}  🛡️ Policy → :console#{RESET}"
puts
sleep(0.5)

# IRB: exit (Matrix)
irb_line
type_effect("exit")
puts
sleep(0.3)
puts "#{WHITE}  Welcome... to the real world, Neo. 🕶️#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# ACT 6: /policy
# ═══════════════════════════════════════════════════════════════
sleep(0.6)
prompt_line
type_effect("/policy")
puts
sleep(0.3)
puts
puts "#{TOOL}  🛡️  Active Policy: :console#{RESET}"
puts "#{DIM}  ╭──────────────────────────────────────────╮#{RESET}"
puts "#{DIM}  │  #{RESET}#{GREEN}✅ AUTO-ALLOW#{RESET}                           #{DIM}│#{RESET}"
puts "#{DIM}  │  #{RESET}  Read tools, safe cmds, safe git"
puts "#{DIM}  │                                          │#{RESET}"
puts "#{TOOL}  │  ⚠️  CONFIRM (ASK)                       │#{RESET}"
puts "#{DIM}  │  #{RESET}  Write tools, shell commands"
puts "#{DIM}  │                                          │#{RESET}"
puts "#{RED}  │  🚫 HARD DENY (BLOCKED)                  │#{RESET}"
puts "#{DIM}  │  #{RESET}  rm -rf, mkfs, shutdown, reboot"
puts "#{DIM}  │  #{RESET}  git push --force, git reset --hard"
puts "#{DIM}  ╰──────────────────────────────────────────╯#{RESET}"
puts

# ═══════════════════════════════════════════════════════════════
# FINALE: /quit
# ═══════════════════════════════════════════════════════════════
sleep(0.8)
prompt_line
type_effect("/quit")
puts
sleep(0.3)
puts "#{DIM}👋 Console closed.#{RESET}"
puts
