# frozen_string_literal: true

# Interactive REPL console for Antigravity SDK.
# Renders thinking in gray italic, responses in bold cyan.
# Tool calls shown inline. Ctrl-O toggles thinking expansion.
#
# Usage:
#   console = Antigravity::Console.new
#   console.start!
#
# Or via CLI:
#   rv run ruby examples/10_console.rb
#
module Antigravity
  class Console
    THINKING_STYLE = "\e[3;90m"  # italic + gray
    CONTENT_STYLE  = "\e[1;36m"  # bold + cyan
    TOOL_STYLE     = "\e[33m"    # yellow
    DIM_STYLE      = "\e[2m"     # dim
    RESET          = "\e[0m"
    PROMPT         = "\e[31m\u2666\e[0m\e[1;35magy>\e[0m "  # red diamond + bold magenta agy>
    MAX_COLLAPSED  = 76  # max chars for collapsed thinking line

    attr_reader :thinking_expanded, :system_instruction

    def initialize(system_instruction: nil, workspace: nil, model: nil, policy: nil)
      @system_instruction = system_instruction || 'You are a helpful AI assistant. Be concise.'
      @workspace = workspace || Dir.pwd
      @model = model
      @policy = policy  # nil → :auto (reads env)
      @thinking_expanded = false
      @agent = nil
      @turn_count = 0
      @tool_start_times = {}
    end

    # Toggle thinking expansion (collapsed 1-line vs full)
    def toggle_thinking!
      @thinking_expanded = !@thinking_expanded
    end

    # Format thinking text based on current expansion mode
    def format_thinking(text)
      return '' if text.nil? || text.empty?

      if @thinking_expanded
        # Full thinking, each line in gray italic
        lines = text.split("\n").map { |l| "#{THINKING_STYLE}  🤔 #{l}#{RESET}" }
        lines.join("\n")
      else
        # Collapsed: 1 line, truncated at MAX_COLLAPSED chars
        clean = text.gsub("\n", ' ').strip
        display = if clean.length > MAX_COLLAPSED
                    clean[0..MAX_COLLAPSED] + '...'
                  else
                    clean
                  end
        "#{THINKING_STYLE}  🤔 #{display}#{RESET}"
      end
    end

    # Format a tool call for inline display (collapsed or expanded)
    def format_tool_call(name, params_preview, elapsed: nil)
      elapsed_str = elapsed ? " #{DIM_STYLE}[#{elapsed}s]#{RESET}" : ''
      if @thinking_expanded
        "#{TOOL_STYLE}  💾 #{name}(#{params_preview})#{elapsed_str}#{RESET}"
      else
        # Collapsed: tool name + params, truncated, agy-style
        short = "#{name}(#{params_preview})"
        short = short[0..MAX_COLLAPSED] + '...' if short.length > MAX_COLLAPSED
        "#{TOOL_STYLE}  💾 #{short}#{elapsed_str} #{DIM_STYLE}(ctrl+o to expand)#{RESET}"
      end
    end

    # Parse special commands (returns symbol or nil for regular text)
    def parse_command(input)
      stripped = input.strip
      case stripped.downcase
      when '/quit', '/exit', '/q' then :quit
      when '/think', '/t'        then :toggle_thinking
      when '/help', '/h', '/?'   then :help
      when '/verbose', '/v'      then :toggle_verbose
      when '/clear'              then :clear
      when '/policy'             then :show_policy
      when '/irb'                then :irb_mode
      when /^r!\s*/              then :ruby_eval
      when /^!\s*/               then :shell_exec
      else nil
      end
    end

    # Format metadata footer after each response
    def format_metadata(usage:, thinking_size:, tool_calls:, elapsed:)
      tok = usage[:total_token_count] || 0
      prompt_tok = usage[:prompt_token_count] || 0
      cand_tok = usage[:candidates_token_count] || 0
      think_str = thinking_size > 0 ? " | 🧠 #{thinking_size}B" : ''
      tool_str = tool_calls > 0 ? " | 💾 #{tool_calls} tools" : ''
      "#{DIM_STYLE}  🪙 #{tok} tok (#{prompt_tok}->#{cand_tok})#{think_str}#{tool_str} | ⏱️ #{elapsed}s#{RESET}"
    end

    # Help text — dynamic, shows current workspace/policy/state
    def help_text
      policy_name = @policy || :console
      think_state = @thinking_expanded ? 'EXPANDED 🔍' : 'COLLAPSED 📦'
      ws = @workspace || Dir.pwd
      conv_id = @agent&.conversation&.conversation_id&.slice(0, 8) || '?'
      <<~HELP
        #{THINKING_STYLE}╭─ Richard v#{Antigravity::VERSION} (Antigravity Console) ────╮
        │                                                │
        │  ⌘ Commands                                    │
        │  /think  or Ctrl-O  Toggle thinking expansion │
        │  /help              Show this help             │
        │  /quit              Exit console               │
        │  /clear             Clear screen               │
        │  /policy            Show active safety policy   │
        │  /irb               Enter Ruby sub-REPL         │
        │                                                │
        │  ⌘ Shortcuts                                    │
        │  ! <cmd>            Shell exec  (! ls -la)      │
        │  r! <expr>          Ruby eval   (r! 2+2)        │
        │                                                │
        │  ⌘ Legend                                       │
        │  🤔 Thinking  💬 Response  💾 Tools  ⚡ Shell   │
        │                                                │
        │  ⌘ Session                                      │
        │  📂 #{ws[0..38].ljust(39)}│
        │  🛡️  policy:#{policy_name.to_s.ljust(31)}│
        │  🤔 thinking: #{think_state.ljust(27)}│
        │  🎫 conv: #{conv_id.ljust(33)}│
        ╰────────────────────────────────────────────────╯#{RESET}
      HELP
    end

    # Start the interactive REPL loop
    def start!
      print_banner
      setup_agent!
      setup_tool_hooks!
      setup_ctrl_o!
      repl_loop
    ensure
      @agent&.close!
      puts "\n#{DIM_STYLE}👋 Console closed.#{RESET}"
    end

    private

    def print_banner
      puts
      puts "\e[1;35m💎 Richard v#{Antigravity::VERSION}\e[0m #{DIM_STYLE}(Antigravity Console)#{RESET}"
      puts "\e[2m   Type a question, or /help for commands.#{RESET}"
      puts "\e[2m   🤔 #{THINKING_STYLE}Thinking#{RESET} #{DIM_STYLE}|#{RESET} 💬 #{CONTENT_STYLE}Response#{RESET} #{DIM_STYLE}|#{RESET} 💾 #{TOOL_STYLE}Tools#{RESET}"
      puts "\e[2m   Use Ctrl-O to expand thinking and tool execution#{RESET}"
      puts
    end

    def setup_agent!
      print "#{DIM_STYLE}🔌 Connecting to harness...#{RESET} "
      opts = { system_instruction: @system_instruction }
      opts[:workspace] = @workspace if @workspace
      opts[:model] = @model if @model
      opts[:policy] = @policy || :console
      @agent = Antigravity::Agent.new(**opts)
      @agent.connect!
      policy_name = @policy || :console
      puts "#{Colors.green('connected!')} #{DIM_STYLE}(#{@agent.conversation&.conversation_id&.slice(0, 8)}) 🛡️ policy:#{policy_name}#{RESET}"
      puts
    end

    # Hook into agent's tool lifecycle for inline rendering
    # Conversation emits: tool_name, params, result, duration, tool_id
    def setup_tool_hooks!
      return unless @agent&.hooks

      @agent.hooks.on(:tool_call) do |info|
        name = info[:tool_name] || '?'
        # Format params into a short preview
        params_raw = info[:params]
        params_str = case params_raw
                     when Hash then params_raw.values.first.to_s
                     when String then params_raw
                     else params_raw.to_s
                     end
        params_preview = params_str[0..60]
        params_preview += '...' if params_str.length > 60
        puts format_tool_call(name, params_preview)
      end

      @agent.hooks.on(:tool_result) do |info|
        name = info[:tool_name] || '?'
        result_str = info[:result].to_s
        result_size = result_str.bytesize
        duration = info[:duration]
        elapsed_str = duration ? " #{DIM_STYLE}[#{duration.round(1)}s]#{RESET}" : ''

        # Show result preview (first meaningful line, truncated)
        preview = result_str.split("\n").reject(&:empty?).first.to_s
        preview = preview[0..MAX_COLLAPSED] + '...' if preview.length > MAX_COLLAPSED

        if @thinking_expanded
          puts "#{TOOL_STYLE}  ✅ #{name}#{elapsed_str} #{DIM_STYLE}| #{result_size}B#{RESET}"
          puts "#{DIM_STYLE}     ↪ #{preview}#{RESET}" unless preview.empty?
        else
          # Collapsed: single line with result preview
          short_preview = preview[0..40]
          short_preview += '...' if preview.length > 40
          puts "\e[32m  ● #{RESET}#{TOOL_STYLE}#{name}#{elapsed_str}: #{DIM_STYLE}#{short_preview}#{RESET}"
        end
      end

      @agent.hooks.on(:tool_error) do |info|
        name = info[:tool_name] || '?'
        error = info[:error] || 'unknown error'
        puts "\e[31m  💥 #{name} -- #{error.to_s[0..80]}#{RESET}"
      end
    end

    # Set up Ctrl-O keybinding via Reline
    def setup_ctrl_o!
      # Suppress reline stdlib warning (Ruby 3.4 → 3.5 transition)
      old_verbose = $VERBOSE
      $VERBOSE = nil
      require 'reline'
      $VERBOSE = old_verbose

      # Ctrl-O = "\x0F" (ASCII 15)
      # Bind it to toggle thinking expansion
      Reline::LineEditor.prepend(Module.new do
        # We can't easily inject into Reline's key dispatch,
        # so we use a SIGQUIT-like approach with IO
      end)

      # Alternative: use a thread to watch for Ctrl-O on raw stdin
      # This works alongside Reline because we only intercept Ctrl-O
      @ctrl_o_thread = Thread.new do
        Thread.current.name = 'ctrl-o-watcher'
        loop do
          # Check if Ctrl-O toggle was requested via a signal file
          toggle_file = '/tmp/.antigravity_toggle_think'
          if File.exist?(toggle_file)
            File.delete(toggle_file) rescue nil
            toggle_thinking!
            state = @thinking_expanded ? 'EXPANDED' : 'COLLAPSED'
            $stderr.print "\r#{DIM_STYLE}  🧠 Thinking: #{state}#{RESET}\n"
          end
          sleep 0.5
        rescue => e
          break
        end
      end

      # For Reline-based Ctrl-O, we add a custom key binding
      # Reline.add_dialog_proc doesn't help here, but we can
      # use trap on a custom signal. Most pragmatic: SIGUSR1
      trap('USR1') do
        toggle_thinking!
        state = @thinking_expanded ? 'EXPANDED' : 'COLLAPSED'
        $stderr.write "\r#{DIM_STYLE}  🧠 Thinking: #{state} (Ctrl-O)#{RESET}\n"
      end
    rescue => e
      # If Reline or signal setup fails, /think still works
    end

    def repl_loop
      require 'readline'

      # Suppress reline stdlib warning
      old_verbose = $VERBOSE
      $VERBOSE = nil
      require 'reline'
      $VERBOSE = old_verbose

      # Read from stdin pipe if available (non-interactive mode)
      # Each line becomes a separate turn for multi-turn piped sessions:
      #   (echo q1 ; echo q2 ; echo q3) | just rv-console
      if !$stdin.tty? && !$stdin.eof?
        $stdin.each_line do |line|
          input = line.strip
          next if input.empty?
          puts "#{DIM_STYLE}  📨 #{input}#{RESET}"
          dispatch_input(input)
        end
        return
      end

      # Interactive mode with readline
      Readline.completion_proc = proc { |s| ['/help', '/think', '/quit', '/clear', '!'].grep(/^#{Regexp.escape(s)}/) }

      # Ctrl-O binding via GNU Readline macro (not available in Reline)
      # Falls back to setup_ctrl_o! signal approach + /think command
      if Readline.respond_to?(:parse_and_bind)
        Readline.parse_and_bind('"\C-o": "/think\C-j"')
      end

      loop do
        input = Readline.readline(PROMPT, true)
        break if input.nil?  # Ctrl-D

        input = input.strip
        next if input.empty?

        break if dispatch_input(input) == :quit
      end
    end

    # Dispatch a single input line: handle commands or send to LLM.
    # Returns :quit if the session should end, nil otherwise.
    def dispatch_input(input)
      cmd = parse_command(input)
      case cmd
      when :quit
        return :quit
      when :toggle_thinking
        toggle_thinking!
        state = @thinking_expanded ? 'EXPANDED 🔍' : 'COLLAPSED 📦'
        puts "#{DIM_STYLE}  🤔 Thinking display: #{state}#{RESET}"
      when :help
        puts help_text
      when :clear
        print "\e[2J\e[H"
        print_banner
      when :toggle_verbose
        puts "#{DIM_STYLE}  (verbose toggle -- not yet implemented)#{RESET}"
      when :shell_exec
        shell_cmd = input.strip.sub(/^!\s*/, '')
        puts "#{TOOL_STYLE}  ⚡ #{shell_cmd}#{RESET}"
        system(shell_cmd)
        puts
      when :ruby_eval
        expr = input.strip.sub(/^r!\s*/i, '')
        puts "#{TOOL_STYLE}  💎 #{expr}#{RESET}"
        begin
          result = eval(expr, binding, '(richard)', 1)  # rubocop:disable Security/Eval
          puts "#{CONTENT_STYLE}  => #{result.inspect}#{RESET}"
        rescue => e
          puts "\e[31m  ❌ #{e.class}: #{e.message}#{RESET}"
        end
      when :show_policy
        show_policy_info
      when :irb_mode
        irb_loop
      else
        process_prompt(input)
      end
      nil
    end

    # Persistent Ruby sub-REPL. Every line is eval'd.
    # Exit with 'exit', 'quit', or Ctrl-D to return to Richard.
    IRB_PROMPT = "\e[31m💎\e[0mirb> "

    def irb_loop
      puts "#{DIM_STYLE}  💎 Entering Ruby mode. Type 'exit' or Ctrl-D to return to Richard.#{RESET}"
      irb_binding = binding  # share console instance context
      loop do
        input = Readline.readline(IRB_PROMPT, true)
        break if input.nil?  # Ctrl-D

        input = input.strip
        next if input.empty?
        break if %w[exit quit].include?(input.downcase)

        begin
          result = eval(input, irb_binding, '(irb)', 1)  # rubocop:disable Security/Eval
          puts "#{CONTENT_STYLE}  => #{result.inspect}#{RESET}"
        rescue => e
          puts "\e[31m  ❌ #{e.class}: #{e.message}#{RESET}"
        end
      end
      puts "#{DIM_STYLE}  💎 Back to Richard.#{RESET}"
    end

    def show_policy_info
      policy_name = @policy || :console
      puts
      puts "#{TOOL_STYLE}  🛡️  Active Policy: :#{policy_name}#{RESET}"
      puts "#{DIM_STYLE}  ╭──────────────────────────────────────────╮#{RESET}"
      puts "#{DIM_STYLE}  │  ✅ AUTO-ALLOW                           │#{RESET}"
      puts "#{DIM_STYLE}  │  #{RESET}  Read tools (view_file, grep, list_dir)"
      puts "#{DIM_STYLE}  │  #{RESET}  Safe cmds (ls, pwd, echo, cat, head...)"
      puts "#{DIM_STYLE}  │  #{RESET}  Safe git (status, log, diff, branch)"
      puts "#{DIM_STYLE}  │                                          │#{RESET}"
      puts "#{TOOL_STYLE}  │  ⚠️  CONFIRM (ASK)                       │#{RESET}"
      puts "#{DIM_STYLE}  │  #{RESET}  Write tools (file_edit, write_to_file)"
      puts "#{DIM_STYLE}  │  #{RESET}  All other shell commands"
      puts "#{DIM_STYLE}  │                                          │#{RESET}"
      puts "\e[31m  │  🚫 HARD DENY (BLOCKED)                  │#{RESET}"
      puts "#{DIM_STYLE}  │  #{RESET}  rm -rf, mkfs, dd, shutdown, reboot"
      puts "#{DIM_STYLE}  │  #{RESET}  git push --force, git reset --hard"
      puts "#{DIM_STYLE}  ╰──────────────────────────────────────────╯#{RESET}"
      puts "#{DIM_STYLE}  📂 workspace: #{@workspace || Dir.pwd}#{RESET}"
      puts "#{DIM_STYLE}  Override: Console.new(policy: :turbo)#{RESET}"
      puts
    end

    def process_prompt(prompt)
      @turn_count += 1

      thinking_buf = []
      content_buf = []
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      thinking_line_printed = false

      response = @agent.ask(prompt) do |chunk|
        if chunk.thinking?
          thinking_buf << chunk.thinking
          # Print thinking inline (collapsed or expanded)
          if @thinking_expanded
            # Stream each thinking delta
            print "#{THINKING_STYLE}#{chunk.thinking}#{RESET}"
          else
            # Overwrite single line with latest thinking preview
            combined = thinking_buf.join
            display = combined.gsub("\n", ' ').strip
            display = display[-MAX_COLLAPSED..] || display  # show tail
            display = display[0..MAX_COLLAPSED] + '...' if display.length > MAX_COLLAPSED
            print "\r\e[K#{THINKING_STYLE}  🤔 #{display}#{RESET}"
            thinking_line_printed = true
          end
        end

        if chunk.content?
          # Clear thinking line before first content
          if thinking_line_printed
            print "\r\e[K"
            # Print final collapsed thinking summary
            total_think = thinking_buf.join
            puts format_thinking(total_think) unless total_think.empty?
            thinking_line_printed = false
          end
          content_buf << chunk.content
          print "#{CONTENT_STYLE}#{chunk.content}#{RESET}"
        end
      end

      # Ensure we close the thinking line if no content followed
      if thinking_line_printed
        print "\r\e[K"
        total_think = thinking_buf.join
        puts format_thinking(total_think) unless total_think.empty?
      end

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(1)
      puts unless content_buf.empty?

      # Metadata footer
      thinking_size = thinking_buf.join.bytesize
      puts format_metadata(
        usage: response.usage,
        thinking_size: thinking_size,
        tool_calls: response.tool_calls_count,
        elapsed: elapsed
      )
      puts
    end
  end
end
