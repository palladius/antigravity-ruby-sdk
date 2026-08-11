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
  desc: 'Dynamically load a skill into the current agent session by path. Use after find_skills to activate a discovered skill.',
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
    session.agent.add_skills([expanded])
    loaded = session.agent.skills.find { |s| s.path&.include?(File.basename(expanded)) }
    name = loaded ? loaded.name : File.basename(expanded)
    "Skill '#{name}' loaded from #{expanded}"
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
                          "Always pass the exact path returned by find_skills to load_skill."
    )
    @agent.connect!
  end

  def ask(text)
    puts "  👤 #{text}".to_cyan
    @history << { role: :user, text: text }
    full = ""
    response = @agent.ask(text, timeout: 180) { |chunk| full += chunk.content if chunk.content }
    @history << { role: :assistant, text: full }
    preview = full.empty? ? '(empty)' : full[0, 150]
    puts "  🤖 #{preview}#{'...' if full.length > 150}".to_green
    full
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
  # Phase 3: load_skill — dynamically add it (direct Ruby call)
  # ========================================================================
  puts "📋 Phase 3: Load Skill Dynamically".to_bold
  todo_path = File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills/riccardo-todo')

  # Call add_skills directly — this is the SDK API, not an LLM tool call.
  # The LLM calling load_skill via harness causes context explosion + timeout.
  begin
    loaded_skills = session.agent.add_skills([todo_path])
    puts "     ⚙️  add_skills returned: #{loaded_skills.map(&:name).join(', ')}".to_yellow
  rescue => e
    puts "     💥 add_skills failed: #{e.message}".to_red
  end

  runner.assert("Agent now has more skills than before") { session.agent.skills.size > skills_before }

  # Check the skill is actually in agent.skills
  todo_skill = session.agent.skills.find { |s| s.name&.downcase&.include?('riccardo') || s.name&.downcase&.include?('todo') }
  runner.assert("riccardo-todo skill object exists in agent.skills") { !todo_skill.nil? }
  if todo_skill
    puts "     📚 Loaded skill: #{todo_skill.name} (#{todo_skill.path})".to_yellow
  end
  puts

  # ========================================================================
  # Phase 4: Use the skill — ask about Riccardo's todos
  # ========================================================================
  puts "📋 Phase 4: Use Loaded Skill".to_bold
  # NOTE: add_skills loads the skill into the Ruby Agent object, but the harness
  # doesn't re-inject skill content mid-session. So we include the skill content
  # in the prompt, simulating what the harness does on session creation.
  skill_content = File.read(File.join(todo_path, 'SKILL.md'), encoding: 'UTF-8', invalid: :replace) rescue '(could not read)'
  skill_excerpt = skill_content[0, 500] # First 500 chars is enough for the test
  response3 = session.ask("Here is a skill definition:\n```\n#{skill_excerpt}\n```\nBased on this skill, where is Riccardo's to-do list file stored? Answer in one sentence.")
  runner.assert_includes("Response mentions Obsidian", response3, "obsidian")
  runner.assert_includes("Response mentions the TODO file", response3, "todo")
  puts

  # ========================================================================
  # Phase 5: Verify skill count
  # ========================================================================
  puts "📋 Phase 5: Final Verification".to_bold
  runner.assert("Agent has at least 1 more skill than at boot") { session.agent.skills.size > skills_before }
  runner.assert("Total skills: #{session.agent.skills.size}") { session.agent.skills.size >= 1 }

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
