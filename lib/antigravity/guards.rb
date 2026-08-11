# frozen_string_literal: true

module Antigravity
  module Guards
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
