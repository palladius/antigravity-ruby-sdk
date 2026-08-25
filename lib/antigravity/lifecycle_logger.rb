# frozen_string_literal: true

# Auto-attachable lifecycle logger that prints colorful, compact status lines
# on every hook event. Inspired by Cloud Code's status bar.
#
# Usage:
#   agent = Antigravity::Agent.new
#   Antigravity::LifecycleLogger.attach!(agent)
#
# Or auto-attach via env:
#   ANTIGRAVITY_LIFECYCLE=1
#   RAILS_ENV=test (auto-attaches in test/development)
#
module Antigravity
  class LifecycleLogger
    C = Antigravity::Colors

    # Compact status string — the "Cloud Code status bar" equivalent.
    # Example: "T3 | 1.2k tok | 4 tools | 2.3s"
    def self.status_line(agent)
      turns    = agent.turn_count rescue 0
      summary  = agent.session_summary rescue {}
      tokens   = summary[:total_tokens] || 0
      tok_str  = tokens > 999 ? "#{(tokens / 1000.0).round(1)}k" : tokens.to_s
      tok_str  = "🪙#{tok_str}"
      model    = summary[:model] || agent.model || '?'
      conv_id  = (summary[:conversation_id] || '?')[0..7]

      C.dim("T#{turns} | #{tok_str} tok | #{model} | #{conv_id}")
    end

    def self.attach!(agent, verbose: false)
      new(verbose: verbose).attach(agent)
    end

    def initialize(verbose: false)
      @verbose = verbose
      @session_start_time = nil
      @turn_start_time = nil
      @turn_count = 0
    end

    def attach(agent)
      attach_session_hooks(agent)
      attach_turn_hooks(agent)
      attach_tool_hooks(agent)
    end

    private

    def attach_session_hooks(agent)
      logger = self

      agent.hooks.on(:session_start) do |info|
        logger.instance_variable_set(:@session_start_time, Process.clock_gettime(Process::CLOCK_MONOTONIC))
        model = info[:model] || agent.model || '?'
        conv_id = (info[:conversation_id] || '?')[0..11]
        puts C.gray("\n🪝🟢 #{C.dim("session_start")} | model=#{C.cyan(model)} | conv=#{C.cyan(conv_id)}")
      end

      agent.hooks.on(:indexing_start) do |info|
        ws = info[:workspace] || '?'
        puts C.gray("🪝 📂 #{C.dim("indexing")}       | #{C.blue(ws)}")
      end

      agent.hooks.on(:indexing_done) do |info|
        ws = info[:workspace] || '?'
        elapsed = info[:elapsed] ? "#{info[:elapsed]}s" : '?'
        puts C.gray("🪝 ✅ #{C.dim("indexed")}        | #{C.blue(ws)} | #{C.green(elapsed)}")
      end

      agent.hooks.on(:session_end) do |info|
        elapsed = if logger.instance_variable_get(:@session_start_time)
                    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - logger.instance_variable_get(:@session_start_time)).round(1)
                  else
                    '?'
                  end
        turns = info[:turn_count] || agent.turn_count rescue 0
        summary = agent.session_summary rescue {}
        tokens = summary[:total_tokens] || 0
        tok_str = tokens > 999 ? "#{(tokens / 1000.0).round(1)}k" : tokens.to_s
        puts C.gray("🪝🔴 #{C.dim("session_end")}   | #{C.bold("#{turns} turns")} | 🪙#{tok_str} | #{elapsed}s")
      end
    end

    def attach_turn_hooks(agent)
      logger = self

      agent.hooks.before_prompt do |text|
        logger.instance_variable_set(:@turn_start_time, Process.clock_gettime(Process::CLOCK_MONOTONIC))
        count = logger.instance_variable_get(:@turn_count) + 1
        logger.instance_variable_set(:@turn_count, count)
        preview = text.to_s[0..60].gsub("\n", ' ')
        preview += '...' if text.to_s.length > 60
        status = self.class.status_line(agent) rescue C.dim("T#{count}")
        puts C.gray("🪝 ➡️  #{C.dim("pre_turn")}  T#{count} | #{C.yellow("\"#{preview}\"")} | #{status}")
      end

      agent.hooks.after_response do |response|
        elapsed = if logger.instance_variable_get(:@turn_start_time)
                    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - logger.instance_variable_get(:@turn_start_time)).round(2)
                  else
                    '?'
                  end
        content = response.respond_to?(:content) ? response.content.to_s : response.to_s
        chars = content.length
        lines = content.count("\n") + 1
        preview = content[0..60]&.gsub("\n", ' ') || '(empty)'
        preview += '...' if chars > 60
        thinking_len = response.respond_to?(:thinking) ? (response.thinking&.length || 0) : 0
        tool_count = response.respond_to?(:tool_calls_count) ? (response.tool_calls_count || 0) : 0
        status = self.class.status_line(agent) rescue ''

        parts = ["#{C.green("#{chars}B")} #{C.dim("#{lines}L")}"]
        parts << "#{C.magenta("#{thinking_len}B")} think" if thinking_len > 0
        parts << "#{C.cyan("#{tool_count}")} tools" if tool_count > 0
        parts << "#{C.blue("#{elapsed}s")}"

        puts C.gray("\n🪝 ⬅️  #{C.dim("post_turn")} T#{logger.instance_variable_get(:@turn_count)} | #{parts.join(' | ')} | #{status}")
        if logger.instance_variable_get(:@verbose)
          puts C.dim("     \"#{preview}\"")
        end
      end
    end

    def attach_tool_hooks(agent)
      logger = self

      agent.hooks.on(:tool_call) do |info|
        name = info[:tool_name] || info[:name] || '?'
        params_preview = (info[:params] || {}).keys.join(', ')
        puts C.gray("  🪝 🔧 #{C.dim("tool_call")}  | #{C.cyan(name)}(#{C.dim(params_preview)})")
      end

      agent.hooks.on(:tool_result) do |info|
        name = info[:tool_name] || info[:name] || '?'
        result_str = info[:result].to_s
        result_len = result_str.bytesize rescue 0
        preview = result_str[0..120].gsub("\n", ' ')
        preview += '...' if result_str.length > 120
        duration = info[:duration] ? "#{info[:duration].round(2)}s" : nil
        parts = [C.cyan(name), "#{result_len}B"]
        parts << duration if duration
        puts C.gray("  🪝 ✅ #{C.dim("tool_done")}  | #{parts.join(' | ')}")
        puts C.dim("     → #{C.yellow(preview)}") if result_len > 0
      end

      agent.hooks.on(:tool_blocked) do |info|
        name = info[:tool] || '?'
        reason = info[:reason] || 'policy'
        puts C.red("  🪝 🚫 #{C.dim("tool_deny")}  | #{C.red(name)} — #{reason}")
      end

      agent.hooks.on(:tool_error) do |info|
        name = info[:tool_name] || info[:name] || '?'
        error = info[:error] || info[:message] || '?'
        puts C.red("  🪝 💥 #{C.dim("tool_error")} | #{C.red(name)} — #{error.to_s[0..80]}")
      end
    end
  end
end
