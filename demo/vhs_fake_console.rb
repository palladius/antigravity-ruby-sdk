#!/usr/bin/env ruby
# frozen_string_literal: true

# 🎬 VHS Demo Script — Simulates the Richard console for recording.
# This produces realistic-looking output without needing a real API connection.
# Usage: ruby demo/vhs_fake_console.rb

require 'io/console'

# ANSI styles (matching real console.rb)
DIM       = "\e[2m"
BOLD_CYAN = "\e[1;36m"
THINKING  = "\e[2;3m"
TOOL      = "\e[0;33m"
RED       = "\e[31m"
GREEN     = "\e[32m"
MAGENTA   = "\e[1;35m"
RESET     = "\e[0m"
PROMPT    = "#{RED}♦#{RESET}agy> "

def type_effect(text, delay: 0.04)
  text.each_char do |c|
    print c
    $stdout.flush
    sleep(delay)
  end
end

def fake_thinking(text, delay: 0.02)
  print "  #{THINKING}🤔 "
  type_effect(text, delay: delay)
  puts RESET
end

def fake_tool(name, detail, delay: 0.5)
  puts "  #{TOOL}💾 #{name}(#{detail}) #{DIM}(ctrl+o to expand)#{RESET}"
  sleep(delay)
end

def fake_web_search(query, delay: 0.5)
  puts "  #{TOOL}💾 WebSearch(#{query}) #{DIM}(ctrl+o to expand)#{RESET}"
  sleep(delay)
end

def fake_response(text, delay: 0.025)
  text.each_char do |c|
    print "#{BOLD_CYAN}#{c}#{RESET}"
    $stdout.flush
    sleep(delay)
  end
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

# ─── ACT 1: Banner ───────────────────────────────────────────
puts
puts "#{MAGENTA}💎 Richard v0.5.1#{RESET} #{DIM}(Antigravity Console)#{RESET}"
puts "#{DIM}   Type a question, or /help for commands.#{RESET}"
puts "#{DIM}   🤔 #{THINKING}Thinking#{RESET} #{DIM}|#{RESET} 💬 #{BOLD_CYAN}Response#{RESET} #{DIM}|#{RESET} 💾 #{TOOL}Tools#{RESET}"
puts "#{DIM}   Use Ctrl-O to expand thinking and tool execution#{RESET}"
puts
print "#{DIM}🔌 Connecting to harness...#{RESET} "
sleep(1.2)
puts "#{GREEN}connected!#{RESET} #{DIM}(a3f7c2b1) 🛡️ policy:console#{RESET}"
puts

# ─── ACT 2: Simple greeting ──────────────────────────────────
sleep(0.8)
prompt_line
type_effect("Ciao! Come stai? Sono Riccardo 🇮🇹")
puts
sleep(0.5)
fake_thinking("Un saluto italiano! Rispondiamo con calore...")
sleep(0.3)
fake_response("Ciao Riccardo! 🇮🇹 Sto benissimo, grazie! Sono Richard, la tua console")
fake_response("Antigravity. Come posso aiutarti oggi? 🎉")
fake_metadata(tok: 342, prompt_tok: 128, cand_tok: 45, elapsed: 1.2)

# ─── ACT 3: Web search ───────────────────────────────────────
sleep(1.0)
prompt_line
type_effect("Cerca le ultime notizie su Ferrara")
puts
sleep(0.5)
fake_thinking("L'utente vuole notizie su Ferrara. Cerco sul web...")
fake_web_search("Ferrara ultime notizie 2026")
fake_web_search("Ferrara eventi estate agosto 2026")
sleep(0.3)
fake_response("Ecco le ultime da Ferrara! 🏰")
fake_response("")
fake_response("📰 **Festival del Buskers 2026** — Dal 22 al 25 agosto, il leggendario")
fake_response("   festival di artisti di strada torna nelle vie del centro storico.")
fake_response("🏛️ **Palazzo dei Diamanti** — Nuova mostra su De Chirico aperta fino")
fake_response("   a ottobre. Record di visitatori nel primo weekend.")
fake_response("⚽ **SPAL** — Vittoria 2-1 contro il Modena in Serie B, gol di testa")
fake_response("   al 92'. Ferrara in festa!")
fake_metadata(tok: 51372, prompt_tok: 48996, cand_tok: 745, tools: 2, elapsed: 4.8)

# ─── ACT 4: /help command ────────────────────────────────────
sleep(1.0)
prompt_line
type_effect("/help")
puts
sleep(0.3)

ws = "/Users/ricc/git/antigravity-ruby-sdk-t001"
puts <<~HELP
  #{THINKING}╭─ Richard v0.5.1 (Antigravity Console) ────╮
  │                                                │
  │  ⌘ Commands                                    │
  │  /think  or Ctrl-O  Toggle thinking expansion │
  │  /help              Show this help             │
  │  /quit              Exit console               │
  │  /clear             Clear screen               │
  │  /policy            Show active safety policy   │
  │                                                │
  │  ⌘ Shortcuts                                    │
  │  ! <cmd>            Shell exec  (! ls -la)      │
  │  r! <expr>          Ruby eval   (r! 2+2)        │
  │                                                │
  │  ⌘ Legend                                       │
  │  🤔 Thinking  💬 Response  💾 Tools  ⚡ Shell   │
  │                                                │
  │  ⌘ Session                                      │
  │  📂 #{ws.ljust(39)}│
  │  🛡️  policy:console                       │
  │  🤔 thinking: COLLAPSED 📦               │
  │  🎫 conv: a3f7c2b1                             │
  ╰────────────────────────────────────────────────╯#{RESET}
HELP

# ─── ACT 5: Shell exec ───────────────────────────────────────
sleep(1.0)
prompt_line
type_effect("! pwd")
puts
sleep(0.2)
puts "  #{TOOL}⚡ pwd#{RESET}"
puts "/Users/ricc/git/antigravity-ruby-sdk-t001"
puts

# ─── ACT 6: Ruby eval ────────────────────────────────────────
sleep(0.8)
prompt_line
type_effect("r! Antigravity::VERSION")
puts
sleep(0.2)
puts "  #{TOOL}💎 Antigravity::VERSION#{RESET}"
puts "  #{BOLD_CYAN}=> \"0.5.1\"#{RESET}"
puts

sleep(0.8)
prompt_line
type_effect('r! {name: "Richard", policy: :console, workspace: Dir.pwd, ruby: RUBY_VERSION}')
puts
sleep(0.2)
puts "  #{TOOL}💎 {name: \"Richard\", policy: :console, ...}#{RESET}"
puts "  #{BOLD_CYAN}=> {name: \"Richard\", policy: :console, workspace: \"/Users/ricc/git/antigravity-ruby-sdk-t001\", ruby: \"3.4.5\"}#{RESET}"
puts

# ─── ACT 7: Policy check ─────────────────────────────────────
sleep(0.8)
prompt_line
type_effect("/policy")
puts
sleep(0.3)
puts
puts "#{TOOL}  🛡️  Active Policy: :console#{RESET}"
puts "#{DIM}  ╭──────────────────────────────────────────╮#{RESET}"
puts "#{DIM}  │  #{RESET}#{GREEN}✅ AUTO-ALLOW#{RESET}                           #{DIM}│#{RESET}"
puts "#{DIM}  │  #{RESET}  Read tools (view_file, grep, list_dir)"
puts "#{DIM}  │  #{RESET}  Safe cmds (ls, pwd, echo, cat, head...)"
puts "#{DIM}  │  #{RESET}  Safe git (status, log, diff, branch)"
puts "#{DIM}  │                                          │#{RESET}"
puts "#{TOOL}  │  ⚠️  CONFIRM (ASK)                       │#{RESET}"
puts "#{DIM}  │  #{RESET}  Write tools (file_edit, write_to_file)"
puts "#{DIM}  │  #{RESET}  All other shell commands"
puts "#{DIM}  │                                          │#{RESET}"
puts "#{RED}  │  🚫 HARD DENY (BLOCKED)                  │#{RESET}"
puts "#{DIM}  │  #{RESET}  rm -rf, mkfs, dd, shutdown, reboot"
puts "#{DIM}  │  #{RESET}  git push --force, git reset --hard"
puts "#{DIM}  ╰──────────────────────────────────────────╯#{RESET}"
puts "#{DIM}  📂 workspace: /Users/ricc/git/antigravity-ruby-sdk-t001#{RESET}"
puts "#{DIM}  Override: Console.new(policy: :turbo)#{RESET}"
puts

# ─── FINALE: Quit ────────────────────────────────────────────
sleep(1.2)
prompt_line
type_effect("/quit")
puts
sleep(0.3)
puts "#{DIM}👋 Console closed.#{RESET}"
puts
