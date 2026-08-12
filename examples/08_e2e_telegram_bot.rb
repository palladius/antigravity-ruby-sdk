#!/usr/bin/env ruby
# frozen_string_literal: true

# E2E Test for Telegram Bot Agent Pipeline
# ==========================================
# Tests the EXACT same agent setup as 08_skill_telegram_bot.rb
# but without Telegram — talks to the agent directly.
#
# Usage:
#   rv run ruby examples/08_e2e_telegram_bot.rb
#   just rv-e2e-telegram
#
# What it tests:
#   1. find_skills tool discovers skills by keyword
#   2. load_skill tool dynamically adds a skill to the agent
#   3. Agent uses the newly loaded skill to answer questions
#   4. Session reset works correctly

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'websocket', '~> 1.2'
  gem 'dotenv', '~> 3.0'
  gem 'base64'
end

require 'json'
require 'timeout'
require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __FILE__))

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'antigravity'
require 'json'
require 'fileutils'

E2E_VERSION = '0.1.0'

# --- Terminal Color Helpers ---
module TermColor
  CODES = { cyan: 36, green: 32, red: 31, yellow: 33, gray: 90, bold: 1, magenta: 35 }.freeze
  CODES.each do |name, code|
    define_method("to_#{name}") { "\e[#{code}m#{self}\e[0m" }
  end
end
String.include(TermColor)

# --- Test Framework ---
class E2ERunner
  attr_reader :passed, :failed, :errors, :total_expected

  def initialize(total_expected: 0)
    @passed = 0
    @failed = 0
    @errors = []
    @test_num = 0
    @total_expected = total_expected
  end

  def assert(description, &block)
    @test_num += 1
    print "  #{@test_num}. #{description}... "
    result = block.call
    if result
      puts "✅ PASS".to_green
      @passed += 1
    else
      puts "❌ FAIL".to_red
      @failed += 1
      @errors << "Test #{@test_num}: #{description}"
    end
  rescue => e
    puts "💥 ERROR: #{e.message[0, 100]}".to_red
    @failed += 1
    @errors << "Test #{@test_num}: #{description} — #{e.class}: #{e.message[0, 80]}"
  end

  def assert_includes(description, text, needle)
    assert("#{description} (contains '#{needle[0,30]}')") do
      text.downcase.include?(needle.downcase)
    end
  end

  def summary
    total_run = @passed + @failed
    not_run = [@total_expected - total_run, 0].max
    puts
    puts "=" * 50
    if @failed == 0 && not_run == 0
      puts "🎉 ALL #{total_run} TESTS PASSED!".to_green.to_bold
    elsif @failed == 0 && not_run > 0
      puts "⚠️  #{@passed}/#{@total_expected} passed, #{not_run} DID NOT RUN (crash?)".to_yellow.to_bold
    else
      puts "💔 #{@failed}/#{total_run} TESTS FAILED:".to_red.to_bold
      @errors.each { |e| puts "   ❌ #{e}".to_red }
    end
    puts "=" * 50
    @failed == 0 && not_run == 0
  end
end

# --- Reuse the EXACT same tool definitions as the bot ---
SKILL_SEARCH_DIRS = [
  File.expand_path('~/.gemini/config/skills'),
  File.expand_path('~/.gemini/config/plugins'),
  File.expand_path('~/git/skillume/skills'),
  File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills'),
  File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-public-goodies/skills'),
].select { |d| Dir.exist?(d) }

SESSIONS = {}
TOOLS = []

TOOLS << Antigravity::Tool.define(:find_skills,
  desc: 'Search for available skills by name/keyword across known directories. Returns names, paths, descriptions.',
  params: { query: { type: :string, desc: 'Search keyword', required: false } }
) { |query: ''|
  results = []
  SKILL_SEARCH_DIRS.each do |dir|
    Dir.glob(File.join(dir, '**/SKILL.md')).each do |skill_file|
      skill_dir = File.dirname(skill_file)
      skill_name = File.basename(skill_dir)
      if query.empty? || skill_name.downcase.include?(query.downcase)
        content = File.read(skill_file, encoding: 'UTF-8', invalid: :replace, undef: :replace) rescue ''
        desc = content.match(/^description:\s*(.+)$/i)&.[](1)&.strip || '(no description)'
        results << "#{skill_name}: #{desc[0, 80]}\n  path: #{skill_dir}"
      end
    end
  end
  results.empty? ? "No skills matching '#{query}'." : "Found #{results.size} skills:\n\n#{results.join("\n\n")}"
}

TOOLS << Antigravity::Tool.define(:load_skill,
  desc: 'Dynamically load a skill into the current agent session by path. Returns the full skill content so you can use it immediately.',
  params: {
    skill_path: { type: :string, desc: 'Full path to the skill directory (containing SKILL.md)' },
    chat_id: { type: :string, desc: 'Current chat ID', required: false }
  }
) { |skill_path:, chat_id: nil|
  expanded = File.expand_path(skill_path)
  skill_md = File.join(expanded, 'SKILL.md')
  unless File.exist?(skill_md)
    next "Skill not found at #{expanded} (no SKILL.md)"
  end
  session = SESSIONS.values.last
  unless session
    next "No active session to load skill into."
  end
  begin
    content = File.read(skill_md, encoding: 'UTF-8', invalid: :replace, undef: :replace)
    session.agent.add_skills([expanded])
    loaded = session.agent.skills.find { |s| s.path&.include?(File.basename(expanded)) }
    name = loaded ? loaded.name : File.basename(expanded)
    # Return the FULL skill content so the LLM has it in context immediately.
    # This is how real dynamic skill loading works — the tool response IS the knowledge.
    "Skill '#{name}' loaded successfully from #{expanded}.\n\n--- SKILL CONTENT ---\n#{content}\n--- END SKILL ---"
  rescue => e
    "Failed to load skill: #{e.message}"
  end
}

# --- ChatSession (same as bot) ---
class ChatSession
  attr_reader :agent, :history

  def initialize(skills: [], tools: [])
    @history = []
    @agent = Antigravity::Agent.new(
      skills: skills,
      tools: tools,
      log_file: 'log/e2e_test.jsonl',
      system_instruction: "You are a test assistant. Be extremely concise. " \
                          "You MUST use tools when asked. NEVER describe what you would do — call the tool immediately. " \
                          "When asked to find a skill, call find_skills. When asked to load a skill, call load_skill. " \
                          "Always pass the exact path returned by find_skills to load_skill. " \
                          "When asked about information from a loaded skill, answer ONLY from the skill's content — " \
                          "do NOT use find, list_dir, grep_search or any filesystem tools. The skill already contains the answer."
    )
    @agent.connect!

    # Dynamic single-line status — overwrites in-place like a TUI spinner
    @_status = { state: 'IDLE', dots: '', tool: nil, msg_count: 0, started: Time.now, active: false }
    @agent.hooks.on(:ws_message) do |msg|
      st = @_status
      st[:msg_count] += 1

      if (s = msg[:stepUpdate])
        if s[:target].to_s =~ /ENVIRONMENT/ && s[:textDelta] && !s[:textDelta].empty?
          st[:tool] = s[:textDelta][0, 50]
          st[:dots] = ''
        elsif s[:state].to_s =~ /ERROR/ && (s[:errorMessage] || s[:textDelta])
          err = (s[:errorMessage] || s[:textDelta])[0, 50]
          st[:tool] = "❌ #{err}"
          st[:dots] = ''
        elsif s[:thinkingDelta] && !s[:thinkingDelta].empty?
          st[:dots] += '💭'
          st[:tool] = nil
        elsif s[:textDelta] && !s[:textDelta].empty? && s[:target].to_s =~ /USER/
          st[:dots] += '·'
          st[:tool] = nil
        end
      elsif (t = msg[:trajectoryStateUpdate])
        st[:state] = t[:state].to_s.sub('STATE_', '')
        st[:dots] = ''
        st[:tool] = nil
      end

      _render_status
    end

    # Background ticker — updates ⏳ every second even when no WS messages arrive
    @_ticker = Thread.new do
      loop do
        sleep 1
        _render_status if @_status[:active]
      end
    end
    @_ticker.abort_on_exception = false
  end

  def _render_status
    st = @_status
    icon = case st[:state]
           when /RUNNING/ then '🏃'
           when /IDLE/    then '😴'
           when /CANCEL/  then '🛑'
           else '⏳'
           end

    elapsed = (Time.now - st[:started]).to_i
    line = "     #{icon} #{st[:state].downcase}"
    line += " 🔧 #{st[:tool]}" if st[:tool]
    line += " #{st[:dots]}" unless st[:dots].empty?
    line += " ⏳#{elapsed}s #{st[:msg_count]}↕"

    print "\r\e[K#{line[0, 79]}"
    $stdout.flush
  end

  def ask(text, wall_timeout: 180)
    puts "  👤 #{text}".to_cyan
    @history << { role: :user, text: text }
    @_status.merge!(started: Time.now, msg_count: 0, dots: '', tool: nil, active: true)
    full = ""
    Timeout.timeout(wall_timeout, Timeout::Error, "Wall-clock timeout after #{wall_timeout}s") do
      @agent.ask(text, timeout: wall_timeout) { |chunk| full += chunk.content if chunk.content }
    end
    @history << { role: :assistant, text: full }
    preview = full.empty? ? '(empty)' : full[0, 150]
    print "\r\e[K"
    puts "  🤖 #{preview}#{'...' if full.length > 150}".to_green
    full
  ensure
    @_status[:active] = false
    print "\r\e[K"
    $stdout.flush
  end

  def close!
    @agent.close! rescue nil
  end
end

# ==========================================================================
# MAIN
# ==========================================================================
puts
puts "🧪 E2E Test: Telegram Bot Agent Pipeline".to_bold
puts "   v#{E2E_VERSION}".to_magenta
puts "=" * 50
puts "🔍 Skill directories: #{SKILL_SEARCH_DIRS.size}"
puts "🛠️  Tools: #{TOOLS.map(&:tool_name).join(', ')}"
puts

runner = E2ERunner.new(total_expected: 11)
session = nil

begin
  # ========================================================================
  # Phase 0: Sanity — skill directories exist
  # ========================================================================
  puts "📋 Phase 0: Sanity Checks".to_bold
  runner.assert("At least 1 skill search directory exists") { SKILL_SEARCH_DIRS.size >= 1 }
  runner.assert("riccardo-todo skill exists on disk") do
    File.exist?(File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills/riccardo-todo/SKILL.md'))
  end
  puts

  # ========================================================================
  # Phase 1: Connect agent + session
  # ========================================================================
  puts "📋 Phase 1: Agent Connection".to_bold
  # Override timeout for e2e — tool calls need more than 60s
  Antigravity.config.timeout_llm = 180
  puts "   ⏱️  Timeout: #{Antigravity.config.timeout_llm}s".to_gray
  metaskill = File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills/metaskill')
  boot_skills = File.exist?(File.join(metaskill, 'SKILL.md')) ? [metaskill] : []
  session = ChatSession.new(skills: boot_skills, tools: TOOLS)
  SESSIONS[1] = session  # Register so load_skill can find it

  runner.assert("Agent connected successfully") { session.agent != nil }
  runner.assert("Agent starts with 0 or 1 skills (metaskill only)") { session.agent.skills.size <= 1 }
  skills_before = session.agent.skills.size
  puts

  # ========================================================================
  # Phase 2: find_skills — discover riccardo-todo
  # ========================================================================
  puts "📋 Phase 2: Find Skills (riccardo-todo)".to_bold
  response1 = session.ask("Call find_skills with query 'riccardo-todo' right now.")
  runner.assert_includes("Response mentions riccardo-todo", response1, "riccardo-todo")
  runner.assert_includes("Response contains a path", response1, "/skills/riccardo-todo")
  puts

  # ========================================================================
  # Phase 3: Load skill via session restart (v1.0 approach)
  # ========================================================================
  # v1.0 LIMITATION: The harness can't inject new skill content mid-session.
  # The LLM calling load_skill with full SKILL.md content causes a WebSocket
  # timeout (>180s). Until GH#15 is resolved (full skill directory support),
  # we restart the session with the skill pre-loaded — same as /reset in bot.
  #
  # Future (GH#15): load_skill should handle full skill dirs (scripts/,
  # resources/, etc.) and inject mid-session without restart.
  puts "📋 Phase 3: Load Skill (session restart — v1.0)".to_bold
  todo_path = File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills/riccardo-todo')

  puts "     🔌 Closing session...".to_gray
  session.close!
  SESSIONS.delete(1)

  new_skills = boot_skills + [todo_path]
  puts "     🔄 Restarting with skills: #{new_skills.map { |s| File.basename(s) }.join(', ')}".to_cyan
  session = ChatSession.new(skills: new_skills, tools: TOOLS)
  SESSIONS[1] = session

  runner.assert("Session reconnected") { session.agent != nil }
  runner.assert("Agent has more skills than before") { session.agent.skills.size > skills_before }

  todo_skill = session.agent.skills.find { |s| s.name&.downcase&.include?('riccardo') || s.name&.downcase&.include?('todo') }
  runner.assert("riccardo-todo in agent.skills") { !todo_skill.nil? }
  if todo_skill
    puts "     📚 Loaded: #{todo_skill.name} (#{todo_skill.path})".to_yellow
  end
  puts

  # ========================================================================
  # Phase 4: Use the skill — harness provides skill context natively
  # ========================================================================
  puts "📋 Phase 4: Use Loaded Skill".to_bold
  # The harness injected riccardo-todo at session creation.
  # We explicitly reference the skill to prevent the model from brute-forcing
  # filesystem searches (find commands timeout on large directories).
  response3 = ""
  max_retries = 2
  phase4_prompt = "According to the riccardo-todo skill you have loaded, " \
                  "where is Riccardo's to-do list file stored? " \
                  "Answer based on the skill instructions only — do NOT search the filesystem."
  (1 + max_retries).times do |attempt|
    begin
      response3 = session.ask(phase4_prompt, wall_timeout: 60)
      break unless response3.strip.empty?
      if attempt < max_retries
        puts "  ⚠️  Empty response (attempt #{attempt + 1}/#{1 + max_retries}), retrying...".to_yellow
      end
    rescue => e
      if attempt < max_retries
        puts "  ⚠️  Error: #{e.message[0,60]} (attempt #{attempt + 1}/#{1 + max_retries}), resetting session...".to_yellow
        session.close! rescue nil
        session = ChatSession.new(skills: boot_skills + [todo_path], tools: TOOLS)
      else
        puts "  💥 Phase 4 failed after #{1 + max_retries} attempts: #{e.message[0,100]}".to_red
      end
    end
  end
  runner.assert_includes("Response mentions Obsidian", response3, "obsidian")
  runner.assert_includes("Response mentions TODO file", response3, "todo")
  puts

  # ========================================================================
  # Phase 5: Verify final state
  # ========================================================================
  puts "📋 Phase 5: Final Verification".to_bold
  runner.assert("Session has riccardo-todo skill") { session.agent.skills.any? { |s| s.name&.include?('riccardo-todo') } }
  runner.assert("Total skills: #{session.agent.skills.size}") { session.agent.skills.size >= 2 }

  skill_names = session.agent.skills.map(&:name).compact
  puts "     📚 All loaded skills: #{skill_names.join(', ')}".to_yellow
  puts

rescue => e
  puts "\n💥 FATAL ERROR: #{e.class}: #{e.message}".to_red
  puts e.backtrace.first(5).join("\n").to_gray
ensure
  session&.close!
end

# --- Report ---
success = runner.summary
exit(success ? 0 : 1)
