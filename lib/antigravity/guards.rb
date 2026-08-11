# frozen_string_literal: true

require "logger"
require "fileutils"

module Antigravity
  module Guards
    # Configurable opt-in logger guard supporting file loggers and Rails.logger
    class AgentLogger
      attr_reader :logger

      def initialize(log_target = "log/antigravity.log", level: Logger::INFO)
        if log_target.is_a?(String)
          FileUtils.mkdir_p(File.dirname(log_target)) rescue nil
          @logger = ::Logger.new(log_target)
        elsif log_target.respond_to?(:info)
          @logger = log_target
        else
          @logger = ::Logger.new($stdout)
        end
        @logger.level = level if @logger.respond_to?(:level=)
      end

      def before_prompt(prompt_text)
        @logger.info("[Antigravity::Prompt] User: '#{prompt_text}'")
      end

      def after_response(response)
        @logger.info("[Antigravity::Response] Assistant (#{response.model_id}): #{response.content.strip}")
      end

      def before_tool_call(tool_name, params)
        @logger.info("[Antigravity::Tool] Executing '#{tool_name}' with params: #{params.inspect}")
      end

      def after_tool_call(tool_name, params, result)
        @logger.info("[Antigravity::Tool] Result for '#{tool_name}': #{result}")
        result
      end

      def attach_to(agent)
        logger_guard = self
        agent.before_prompt { |p| logger_guard.before_prompt(p) }
        agent.after_response { |r| logger_guard.after_response(r) }
        agent.before_tool_call { |t, p| logger_guard.before_tool_call(t, p) }
        agent.after_tool_call { |t, p, r| logger_guard.after_tool_call(t, p, r) }
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
