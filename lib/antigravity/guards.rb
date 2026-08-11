# frozen_string_literal: true

require "json"
require "fileutils"

module Antigravity
  module Guards
    # Dual-output logger guard:
    #   1. JSONL (log/antigravity.jsonl) — structured, machine-parseable, full data
    #   2. Compact log (log/antigravity.log) — human-readable one-liners with byte sizes
    # Falls back to Rails.logger for both if available.
    class AgentLogger
      attr_reader :target_description

      def initialize(log_target = nil, level: :info, silent_notice: false)
        resolved = resolve_log_target(log_target)

        if resolved.is_a?(String)
          dir = File.dirname(resolved)
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

          # Fat JSONL log
          @jsonl = File.open(resolved, 'a')
          @jsonl.sync = true

          # Skinny compact log (same dir, .log extension)
          compact_path = resolved.sub(/\.jsonl$/, '.log')
          @compact = File.open(compact_path, 'a')
          @compact.sync = true

          @rails_logger = nil
          @target_description = resolved
        elsif resolved.respond_to?(:info)
          @jsonl = nil
          @compact = nil
          @rails_logger = resolved
          @target_description = "Rails.logger"
        else
          @jsonl = $stdout
          @compact = nil
          @rails_logger = nil
          @target_description = "$stdout"
        end

        @level = level

        unless silent_notice
          puts "#{Antigravity.emoji(:logger)} Logging to #{@target_description}"
        end
      end

      def before_prompt(prompt_text)
        size = prompt_text.to_s.bytesize
        log_jsonl('prompt', { user_input: prompt_text })
        log_compact("#{Antigravity.emoji(:prompt)} PROMPT #{size}B | #{prompt_text.to_s[0, 80]}")
      end

      def after_response(response)
        content = response.content&.strip || ''
        log_jsonl('response', {
          model: response.model_id,
          content: content,
          tokens: response.usage[:total_token_count],
          tool_calls: response.tool_calls_count,
          steps: response.steps&.length
        })
        log_compact("#{Antigravity.emoji(:response)} RESPONSE #{content.bytesize}B | " \
                    "tokens=#{response.usage[:total_token_count]} " \
                    "tools=#{response.tool_calls_count} " \
                    "steps=#{response.steps&.length} " \
                    "model=#{response.model_id}")
      end

      def before_tool_call(tool_name, params)
        params_size = params.to_s.bytesize
        log_jsonl('tool_call', { tool: tool_name, params: params })
        log_compact("#{Antigravity.emoji(:tool)} TOOL_CALL #{tool_name} params=#{params_size}B")
      end

      def after_tool_call(tool_name, params, result)
        blocked = result.to_s.include?("TOOL BLOCKED")
        result_size = result.to_s.bytesize
        log_jsonl('tool_result', {
          tool: tool_name,
          result: result.to_s[0, 500],
          blocked: blocked
        })
        status = blocked ? 'BLOCKED' : 'OK'
        log_compact("#{blocked ? Antigravity.emoji(:tool_blocked) : Antigravity.emoji(:tool_result)} TOOL_RESULT #{tool_name} #{status} result=#{result_size}B")
        result
      end

      def sidecar_event(event_type, payload)
        log_jsonl('sidecar', { type: event_type.to_s, payload: payload })
        log_compact("#{Antigravity.emoji(:sidecar)} SIDECAR :#{event_type}")
      end

      def attach_to(agent)
        logger_guard = self
        agent.before_prompt { |p| logger_guard.before_prompt(p) }
        agent.after_response { |r| logger_guard.after_response(r) }
        agent.before_tool_call { |t, p| logger_guard.before_tool_call(t, p) }
        agent.after_tool_call { |t, p, r| logger_guard.after_tool_call(t, p, r) }
      end

      private

      def ts
        Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
      end

      def log_jsonl(event, data)
        if @rails_logger
          @rails_logger.info("[Antigravity] #{event}: #{data.inspect}")
        elsif @jsonl
          entry = { ts: ts, event: event, pid: Process.pid }.merge(data.compact)
          @jsonl.puts(JSON.generate(entry))
        end
      end

      def log_compact(line)
        if @compact
          @compact.puts("#{ts} #{line}")
        end
      end

      def resolve_log_target(target)
        return target if target

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger
        elsif ENV["RAILS_ENV"] && !ENV["RAILS_ENV"].empty?
          "log/#{ENV['RAILS_ENV']}.jsonl"
        elsif ENV["RACK_ENV"] && !ENV["RACK_ENV"].empty?
          "log/#{ENV['RACK_ENV']}.jsonl"
        else
          "log/antigravity.jsonl"
        end
      end
    end

    # Configurable opt-in file protection guard
    class FileProtection
      DEFAULT_FILES = [
        /\.env(\..*)?$/i,
        /Gemfile(\.lock)?$/i,
        /config\/secrets\.yml$/i,
        /config\/database\.yml$/i
      ].freeze

      attr_reader :protected_files

      def initialize(files: nil, add: [], remove: [])
        initial_patterns = files ? Array(files) : DEFAULT_FILES
        patterns = initial_patterns.map { |f| f.is_a?(Regexp) ? f : /#{Regexp.escape(f.to_s)}$/i }
        patterns += Array(add).map { |f| f.is_a?(Regexp) ? f : /#{Regexp.escape(f.to_s)}$/i }
        patterns -= Array(remove).map { |f| f.is_a?(Regexp) ? f : /#{Regexp.escape(f.to_s)}$/i }
        @protected_files = patterns.freeze
      end

      def call(_tool_name, params)
        path = extract_path(params)
        return :allow unless path

        if protected_path?(path)
          { status: :deny, reason: "FileProtection Guard: Modifications to '#{path}' are restricted." }
        else
          :allow
        end
      end

      def to_proc
        method(:call).to_proc
      end

      private

      def extract_path(params)
        return nil unless params.is_a?(Hash)
        params[:path] || params["path"] || params[:file] || params["file"] || params[:target]
      end

      def protected_path?(path)
        filename = File.basename(path)
        @protected_files.any? { |pattern| path =~ pattern || filename =~ pattern }
      end
    end

    # Configurable opt-in secret masking filter
    class SecretMasker
      DEFAULT_PATTERNS = [
        /(AIzaSy[A-Za-z0-9_-]{25,45})/,           # Google API Keys
        /(sk-[A-Za-z0-9]{25,50})/,                # OpenAI API Keys
        /(ghp_[A-Za-z0-9]{25,45})/,               # GitHub Tokens
        /(bearer\s+[A-Za-z0-9\._-]{20,})/i       # Bearer Tokens
      ].freeze

      attr_reader :patterns, :replacement

      def initialize(patterns: nil, replacement: "[REDACTED_SECRET]")
        @patterns = (patterns ? Array(patterns) : DEFAULT_PATTERNS).freeze
        @replacement = replacement
      end

      def call(_tool_name, _params, result)
        return result unless result.is_a?(String)

        sanitized = result.dup
        @patterns.each do |pattern|
          sanitized.gsub!(pattern, @replacement)
        end
        sanitized
      end

      def to_proc
        method(:call).to_proc
      end
    end
  end
end
