# frozen_string_literal: true

require "logger"
require "fileutils"

module Antigravity
  module Guards
    # Configurable opt-in logger guard supporting file loggers and Rails.logger
    class AgentLogger
      attr_reader :logger, :target_description

      def initialize(log_target = nil, level: Logger::INFO, silent_notice: false)
        resolved_target = resolve_log_target(log_target)

        if resolved_target.is_a?(String)
          dir = File.dirname(resolved_target)
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
          @logger = ::Logger.new(resolved_target)
          @target_description = resolved_target
        elsif resolved_target.respond_to?(:info)
          @logger = resolved_target
          @target_description = "Rails.logger"
        else
          @logger = ::Logger.new($stdout)
          @target_description = "$stdout"
        end

        @logger.level = level if @logger.respond_to?(:level=)

        unless silent_notice
          puts "#{Antigravity.emoji(:logger)} Logging to #{@target_description}"
        end
      end

      def before_prompt(prompt_text)
        @logger.info("#{Antigravity.emoji(:prompt)} [Antigravity::Prompt] User: '#{prompt_text}'")
      end

      def after_response(response)
        @logger.info("#{Antigravity.emoji(:response)} [Antigravity::Response] Assistant (#{response.model_id}): #{response.content.strip}")
      end

      def before_tool_call(tool_name, params)
        @logger.info("#{Antigravity.emoji(:tool)} [Antigravity::Tool] Executing '#{tool_name}' with params: #{params.inspect}")
      end

      def after_tool_call(tool_name, params, result)
        prefix = result.to_s.include?("TOOL BLOCKED") ? Antigravity.emoji(:tool_blocked) : Antigravity.emoji(:tool_result)
        @logger.info("#{prefix} [Antigravity::Tool] Result for '#{tool_name}': #{result}")
        result
      end

      def sidecar_event(event_type, payload)
        @logger.info("#{Antigravity.emoji(:sidecar)} [Antigravity::Sidecar] Event :#{event_type} payload: #{payload.inspect}")
      end

      def attach_to(agent)
        logger_guard = self
        agent.before_prompt { |p| logger_guard.before_prompt(p) }
        agent.after_response { |r| logger_guard.after_response(r) }
        agent.before_tool_call { |t, p| logger_guard.before_tool_call(t, p) }
        agent.after_tool_call { |t, p, r| logger_guard.after_tool_call(t, p, r) }
      end

      private

      def resolve_log_target(target)
        return target if target

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger
        elsif ENV["RAILS_ENV"] && !ENV["RAILS_ENV"].empty?
          "log/#{ENV['RAILS_ENV']}.log"
        elsif ENV["RACK_ENV"] && !ENV["RACK_ENV"].empty?
          "log/#{ENV['RACK_ENV']}.log"
        else
          "log/antigravity.log"
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
