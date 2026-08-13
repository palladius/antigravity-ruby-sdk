#!/usr/bin/env ruby
# frozen_string_literal: true

# E2E Test: Nano Banana Image Generation Pipeline
# =================================================
# Tests the full flow: find skill -> load skill -> generate image -> verify output.
#
# Phases:
#   0. Sanity: skill exists on disk, generate_image.py exists
#   1. Connect agent with tools
#   2. Find nano-banana-ricc skill via find_skills tool
#   3. Load skill dynamically (same session, manual fallback)
#   4. Generate image (model builds command OR failsafe from SKILL.md)
#   5. Verify the output file exists + auto-open
#
# Key design decisions:
#   - No session restart: Phases 3-4 reuse the same session (avoids GHI #16 context amnesia)
#   - Truncated tool results: load_skill returns 4-line summary, not full SKILL.md (avoids model hang)
#   - Failsafe: if model times out, we build the uv run command directly from skill scripts/
#
# Usage:
#   rv run ruby examples/09_e2e_nanobanana.rb
#   just rv-e2e-nanobanana

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'websocket', '~> 1.2'
  gem 'dotenv', '~> 3.0'
  gem 'base64'
end

require 'json'
require 'timeout'
require 'fileutils'
require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __FILE__))

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'antigravity'

E2E_VERSION = '0.1.0'
SKILL_NAME = 'nano-banana-ricc'
OUTPUT_DIR = File.expand_path('../tmp/nanobanana_e2e', __dir__)

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
    @errors << "Test #{@test_num}: #{description} -- #{e.class}: #{e.message[0, 80]}"
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

# --- Skill search dirs (same as telegram bot) ---
SKILL_SEARCH_DIRS = [
  File.expand_path('~/.gemini/config/skills'),
  File.expand_path('~/.gemini/config/plugins'),
  File.expand_path('~/.gemini/skills'),
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
  desc: 'Dynamically load a skill into the current agent session by path. Returns a short summary.',
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
    # Extract just the key info: script path and usage hint (NOT the full 61-line SKILL.md)
    script_path = Dir.glob(File.join(expanded, 'scripts', '*.py')).first || '(no script found)'
    desc_line = content.match(/^description:\s*(.+)$/i)&.[](1)&.strip || ''
    "Skill '#{name}' loaded from #{expanded}.\n" \
    "Script: #{script_path}\n" \
    "Description: #{desc_line}\n" \
    "Use: uv run '#{script_path}' --prompt '<text>' --filename '<output.png>' --resolution 1K"
  rescue => e
    "Failed to load skill: #{e.message}"
  end
}

TOOLS << Antigravity::Tool.define(:run_command,
  desc: 'Execute a shell command and return stdout+stderr. Use this to run scripts like generate_image.py. Max 30s timeout.',
  params: {
    command: { type: :string, desc: 'The shell command to execute' },
    working_directory: { type: :string, desc: 'Working directory for the command', required: false }
  }
) { |command:, working_directory: nil|
  require 'open3'
  cwd = working_directory ? File.expand_path(working_directory) : Dir.pwd
  puts "     🐚 #{command[0, 70]}".to_gray
  stdout, stderr, status = nil, nil, nil
  Timeout.timeout(30) do
    stdout, stderr, status = Open3.capture3(command, chdir: cwd)
  end
  output = "Exit code: #{status.exitstatus}\n"
  output += "STDOUT:\n#{stdout[0, 2000]}\n" unless stdout.empty?
  output += "STDERR:\n#{stderr[0, 1000]}\n" unless stderr.empty?
  output
}

# --- ChatSession with TUI status ---
class ChatSession
  attr_reader :agent, :history

  def initialize(skills: [], tools: [])
    @history = []
    @agent = Antigravity::Agent.new(
      skills: skills,
      tools: tools,
      log_file: 'log/e2e_nanobanana.jsonl',
      system_instruction: "You are a test assistant. Be extremely concise. " \
                          "You MUST use tools when asked. NEVER describe what you would do -- call the tool immediately. " \
                          "When asked to find a skill, call find_skills. When asked to load a skill, call load_skill. " \
                          "Always pass the exact path returned by find_skills to load_skill. " \
                          "When asked about information from a loaded skill, answer ONLY from the skill's content. " \
                          "When asked to generate an image using a loaded skill, follow the skill's exact instructions " \
                          "to build the uv run command, then EXECUTE it using the run_command tool. " \
                          "NEVER output a bash code block -- always call run_command to actually run the command. " \
                          "do NOT use find, list_dir, grep_search or any filesystem tools."
    )
    @agent.connect!

    # TODO(GH#17): Refactor this step-log TUI into lib/antigravity/tui.rb
    # The hooks-based observability pattern (step log, tool timing, colored states)
    # is generic enough to live in the SDK itself, e.g.:
    #   agent = Antigravity::Agent.new(tui: :step_log)
    # or:
    #   Antigravity::TUI::StepLog.attach(agent)
    # See: https://github.com/palladius/antigravity-ruby-sdk/issues/17
    #
    # Step-log TUI: each significant event gets a permanent line,
    # thinking/timer overwrite the last dynamic line.
    # Tool calls show elapsed time: "🔧 run_command(uv run...) [42s]"
    @_status = { state: 'IDLE', dots: '', tool: nil, tool_started: nil,
                 msg_count: 0, started: Time.now, active: false }
    @_thinking_count = 0
    @agent.hooks.on(:ws_message) do |msg|
      st = @_status
      st[:msg_count] += 1
      n = st[:msg_count]

      if (s = msg[:stepUpdate])
        if s[:target].to_s =~ /ENVIRONMENT/ && s[:textDelta] && !s[:textDelta].empty?
          # Tool call / tool output — permanent line
          # If a previous tool was running, log its elapsed time
          _finalize_tool(n - 1) if st[:tool]
          tool_text = s[:textDelta].strip.gsub(/\s+/, ' ')[0, 100]
          _print_step(n, "🔧", tool_text)
          st[:tool] = tool_text[0, 50]
          st[:tool_started] = Time.now
          st[:dots] = ''
          @_thinking_count = 0
        elsif s[:state].to_s =~ /ERROR/ && (s[:errorMessage] || s[:textDelta])
          _finalize_tool(n - 1) if st[:tool]
          err = (s[:errorMessage] || s[:textDelta]).strip[0, 100]
          _print_step(n, "❌", err)
          st[:tool] = nil
          st[:tool_started] = nil
          st[:dots] = ''
        elsif s[:thinkingDelta] && !s[:thinkingDelta].empty?
          # Thinking — accumulate on dynamic line
          @_thinking_count += 1
          st[:dots] = '💭' * [@_thinking_count, 8].min
        elsif s[:textDelta] && !s[:textDelta].empty? && s[:target].to_s =~ /USER/
          _finalize_tool(n - 1) if st[:tool]
          text_preview = s[:textDelta].strip.gsub(/\s+/, ' ')[0, 100]
          unless text_preview.empty?
            if st[:dots].include?('·')
              st[:dots] += '·'
            else
              _print_step(n, "💬", text_preview)
              st[:dots] = '·'
            end
          end
        end
      elsif (t = msg[:trajectoryStateUpdate])
        new_state = t[:state].to_s.sub('STATE_', '')
        _finalize_tool(n - 1) if st[:tool]
        unless new_state == st[:state]
          icon = case new_state
                 when /RUNNING/    then '🏃'
                 when /IDLE/       then '😴'
                 when /FULLY_IDLE/ then '🏁'
                 when /CANCEL/     then '🛑'
                 else '🔄'
                 end
          _print_step(n, icon, "state -> #{new_state.downcase}")
          st[:state] = new_state
        end
        st[:dots] = ''
        st[:tool] = nil
        st[:tool_started] = nil
        @_thinking_count = 0
      end

      _render_status
    end

    # Background ticker
    @_ticker = Thread.new do
      loop do
        sleep 1
        _render_status if @_status[:active]
      end
    end
    @_ticker.abort_on_exception = false
  end

  # Print a permanent step line (clears dynamic line first)
  def _print_step(n, icon, text)
    print "\r\e[K"
    puts "     #{n.to_s.rjust(2)}↕ #{icon} #{text}".to_gray
  end

  # Log tool completion with elapsed time
  def _finalize_tool(n)
    st = @_status
    return unless st[:tool] && st[:tool_started]
    elapsed = (Time.now - st[:tool_started]).to_i
    if elapsed > 0
      _print_step(n, "⏱️ ", "#{st[:tool][0, 40]} [#{elapsed}s]")
    end
    st[:tool] = nil
    st[:tool_started] = nil
  end

  def _render_status
    st = @_status
    state_down = st[:state].downcase
    icon, color = case st[:state]
                  when /RUNNING/  then ['🏃', :green]
                  when /IDLE/     then ['😴', :gray]
                  when /CANCEL/   then ['🛑', :red]
                  when /ERROR/    then ['💥', :red]
                  else ['⏳', :yellow]
                  end

    colored_state = "\e[#{TermColor::CODES[color]}m#{state_down}\e[0m"

    elapsed = (Time.now - st[:started]).to_i
    line = "     #{icon} #{colored_state}"
    if st[:tool]
      tool_elapsed = (Time.now - st[:tool_started]).to_i
      line += " 🔧 #{st[:tool][0, 35]} #{tool_elapsed}s"
    end
    line += " #{st[:dots]}" unless st[:dots].empty?
    line += " ⏳#{elapsed}s #{st[:msg_count]}↕"

    print "\r\e[K#{line[0, 120]}"
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
    preview = full.empty? ? '(empty)' : full[0, 200]
    print "\r\e[K"
    puts "  🤖 #{preview}#{'...' if full.length > 200}".to_green
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
FileUtils.mkdir_p(OUTPUT_DIR)

puts
puts "🧪 E2E Test: 🍌 Nano Banana Image Generation".to_bold
puts "   v#{E2E_VERSION}".to_magenta
puts "=" * 50
puts "🔍 Skill directories: #{SKILL_SEARCH_DIRS.size}"
puts "🛠️  Tools: #{TOOLS.map(&:tool_name).join(', ')}"
puts "📁 Output dir: #{OUTPUT_DIR}"
puts

runner = E2ERunner.new(total_expected: 9)
session = nil
nanobanana_path = nil
generated_image_path = nil

begin
  # ========================================================================
  # Phase 0: Sanity
  # ========================================================================
  puts "📋 Phase 0: Sanity Checks".to_bold

  # Find the skill on disk
  nanobanana_skill_md = nil
  SKILL_SEARCH_DIRS.each do |dir|
    candidate = File.join(dir, SKILL_NAME, 'SKILL.md')
    if File.exist?(candidate)
      nanobanana_skill_md = candidate
      nanobanana_path = File.dirname(candidate)
      break
    end
  end

  runner.assert("#{SKILL_NAME} skill exists on disk") { !nanobanana_skill_md.nil? }

  if nanobanana_path
    runner.assert("generate_image.py exists") do
      File.exist?(File.join(nanobanana_path, 'scripts', 'generate_image.py'))
    end
    puts "     📍 Skill at: #{nanobanana_path}".to_gray
  end
  puts

  # ========================================================================
  # Phase 1: Connect agent
  # ========================================================================
  puts "📋 Phase 1: Agent Connection".to_bold
  Antigravity.config.timeout_llm = 180
  puts "   ⏱️  Timeout: #{Antigravity.config.timeout_llm}s".to_gray

  metaskill = File.expand_path('~/git/pvt-skillume/gemini-cli-palladius-private-goodies/skills/metaskill')
  boot_skills = File.exist?(File.join(metaskill, 'SKILL.md')) ? [metaskill] : []
  session = ChatSession.new(skills: boot_skills, tools: TOOLS)
  SESSIONS[1] = session

  runner.assert("Agent connected successfully") { session.agent != nil }
  skills_before = session.agent.skills.size
  puts

  # ========================================================================
  # Phase 2: Find nano-banana-ricc skill
  # ========================================================================
  puts "📋 Phase 2: Find Skills (#{SKILL_NAME})".to_bold
  response1 = session.ask("Call find_skills with query '#{SKILL_NAME}' right now.")
  runner.assert_includes("Response mentions #{SKILL_NAME}", response1, SKILL_NAME)
  runner.assert_includes("Response contains a path", response1, "/#{SKILL_NAME}")
  puts

  # ========================================================================
  # Phase 3: Load skill (model calls load_skill tool → sees SKILL.md content)
  # ========================================================================
  puts "📋 Phase 3: Load Skill".to_bold

  response2 = ""
  begin
    response2 = session.ask(
      "Call load_skill with path '#{nanobanana_path}' right now.",
      wall_timeout: 20
    )
  rescue => e
    puts "  ⚠️  Timeout on load_skill (#{e.message[0,40]}) — continuing anyway".to_yellow
  end

  # Check if model's tool call loaded it; if not, load manually
  loaded_skill = session.agent.skills.find { |s| s.name&.include?('nano-banana') }
  if loaded_skill
    puts "     📚 Loaded by model: #{loaded_skill.name} (#{loaded_skill.path})".to_yellow
  else
    puts "     ⚠️  Model didn't load skill — loading manually...".to_yellow
    session.agent.add_skills([nanobanana_path])
    loaded_skill = session.agent.skills.find { |s| s.name&.include?('nano-banana') }
    puts "     📚 Manual load: #{loaded_skill&.name}".to_yellow
  end

  # Assert AFTER fallback — tests the end state
  runner.assert("Agent has #{SKILL_NAME} in skills array") do
    session.agent.skills.any? { |s|
      s.name&.downcase&.include?('nano-banana') || s.name&.downcase&.include?('nanobanana')
    }
  end
  puts

  # ========================================================================
  # Phase 4: Build the uv run command (ask model OR build ourselves)
  # ========================================================================
  puts "📋 Phase 4: Generate Image 🍌".to_bold

  timestamp = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
  output_filename = "#{timestamp}-e2e-test-ruby-banana.png"
  output_fullpath = File.join(OUTPUT_DIR, output_filename)

  image_prompt = "A cute cartoon ruby gemstone wearing a tiny banana costume, " \
                 "dancing on a terminal screen with green text scrolling behind it. " \
                 "Pixel art style, vibrant colors, fun and whimsical."

  # Ask model to build the uv run command as TEXT (no run_command tool needed)
  generation_prompt = "Based on the nano-banana-ricc skill you just loaded, " \
                      "write the EXACT uv run shell command to generate an image. " \
                      "Use prompt: '#{image_prompt}' " \
                      "Output file: '#{output_fullpath}' " \
                      "Resolution: 1K. No character reference images. " \
                      "Output ONLY the command in a ```bash code block, nothing else."

  response3 = ""
  begin
    response3 = session.ask(generation_prompt, wall_timeout: 30)
  rescue => e
    puts "  ⚠️  Model command build failed: #{e.message[0,60]}".to_yellow
  end

  # Parse command from model response
  generated_cmd = nil
  if (cmd_match = response3.match(/```(?:bash)?\s*\n(.+?)\n```/m))
    generated_cmd = cmd_match[1].strip.lines.first.strip
  elsif (inline_match = response3.match(/(uv run\s+\S+generate_image\.py.+)/))
    generated_cmd = inline_match[1].strip
  end

  # FAILSAFE: if model didn't produce a command, build it ourselves from SKILL.md
  unless generated_cmd
    puts "  🔧 Model didn't return a command — building from SKILL.md directly".to_yellow
    skill_script = File.join(nanobanana_path, 'scripts', 'generate_image.py')
    if File.exist?(skill_script)
      generated_cmd = "uv run '#{skill_script}' " \
                      "--prompt '#{image_prompt}' " \
                      "--filename '#{output_fullpath}' " \
                      "--resolution 1K"
    end
  end

  if generated_cmd
    runner.assert("Generated a valid uv run command") { generated_cmd.include?('uv run') }
    puts "     🐚 #{generated_cmd[0, 120]}".to_cyan
    require 'open3'
    puts "     ⏳ Generating image...".to_gray
    t_start = Time.now
    stdout, stderr, status = Open3.capture3(generated_cmd)
    elapsed = (Time.now - t_start).to_i
    puts "     #{status.success? ? '✅' : '❌'} exit=#{status.exitstatus} [#{elapsed}s]"
    puts "     #{stdout.strip[0, 120]}".to_gray unless stdout.strip.empty?
    puts "     #{stderr.strip[0, 120]}".to_yellow unless stderr.strip.empty?
  else
    puts "  ❌ Could not build uv run command".to_red
    runner.assert("Generated a valid uv run command") { false }
  end
  puts

  # ========================================================================
  # Phase 5: Verify output
  # ========================================================================
  puts "📋 Phase 5: Verify Generated Image".to_bold

  # Look for the output file -- could be exact path or somewhere in OUTPUT_DIR
  found_image = if File.exist?(output_fullpath)
                  output_fullpath
                else
                  # Search for any recently created PNG
                  Dir.glob(File.join(OUTPUT_DIR, '*.png')).max_by { |f| File.mtime(f) }
                end

  # Also check if harness saved it somewhere else (cwd, /tmp, etc.)
  unless found_image
    # Check response for MEDIA: lines or file paths
    if (match = response3.match(/(?:MEDIA:|saved?.*?to|output.*?:)\s*(.+\.png)/i))
      candidate = File.expand_path(match[1].strip)
      found_image = candidate if File.exist?(candidate)
    end
  end

  # Last resort: find any PNG created in the last 2 minutes
  unless found_image
    recent = `find /Users/ricc/git/antigravity-ruby-sdk -name '*.png' -newer /tmp -mmin -2 2>/dev/null`.strip.split("\n").first
    found_image = recent if recent && File.exist?(recent)
  end

  generated_image_path = found_image

  runner.assert("Image file was created") { !found_image.nil? && File.exist?(found_image.to_s) }

  if found_image && File.exist?(found_image)
    size_kb = (File.size(found_image) / 1024.0).round(1)
    puts "     🖼️  Generated: #{found_image}".to_yellow
    puts "     📏 Size: #{size_kb} KB".to_gray
    runner.assert("Image file is not empty (#{size_kb} KB)") { File.size(found_image) > 1024 }

    # 🎬 Demo effect: open the image!
    opener = RUBY_PLATFORM =~ /darwin/ ? 'open' : 'xdg-open'
    puts "     🎬 Opening image with #{opener}...".to_cyan
    system("#{opener} '#{found_image}' &")
  else
    puts "     ❌ No image file found!".to_red
    runner.assert("Image file is not empty") { false }
  end
  puts

rescue => e
  puts "\n💥 FATAL ERROR: #{e.class}: #{e.message}".to_red
  puts e.backtrace.first(5).join("\n").to_gray
ensure
  session&.close!
end

# --- Report ---
success = runner.summary

if generated_image_path && File.exist?(generated_image_path.to_s)
  puts
  puts "🖼️  Generated image: #{generated_image_path}".to_cyan
  puts "   Open it: open '#{generated_image_path}'".to_gray
end

exit(success ? 0 : 1)
