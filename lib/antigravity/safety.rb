# frozen_string_literal: true

module Antigravity
  module Safety
    # Pre-hook guardrail to prevent dangerous file edits or destructive operations
    class ProtectedFilesGuard
      PROTECTED_PATTERNS = [
        /\.env(\..*)?$/i,
        /Gemfile(\.lock)?$/i,
        /config\/secrets\.yml$/i,
        /config\/database\.yml$/i,
        /\.git\//i,
        /\/etc\//i
      ].freeze

      attr_reader :blocked_patterns

      def initialize(additional_patterns: [])
        @blocked_patterns = PROTECTED_PATTERNS + additional_patterns
      end

      def call(tool_name, params)
        path = extract_path(params)
        return :allow unless path

        if protected_file?(path)
          { status: :deny, reason: "Security Policy Violation: Modifications to '#{path}' are restricted and require explicit approval." }
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

      def protected_file?(path)
        filename = File.basename(path)
        @blocked_patterns.any? { |pattern| path =~ pattern || filename =~ pattern }
      end
    end

    # Post-hook sanitizer to redact sensitive API keys and tokens from tool outputs
    class SecretMasker
      SECRET_PATTERNS = [
        /(AIzaSy[A-Za-z0-9_-]{25,45})/,           # Google API Keys
        /(sk-[A-Za-z0-9]{25,50})/,                # OpenAI API Keys
        /(ghp_[A-Za-z0-9]{25,45})/,               # GitHub Tokens
        /(bearer\s+[A-Za-z0-9\._-]{20,})/i       # Bearer Tokens
      ].freeze

      def call(_tool_name, _params, result)
        return result unless result.is_a?(String)

        sanitized = result.dup
        SECRET_PATTERNS.each do |pattern|
          sanitized.gsub!(pattern, "[REDACTED_SECRET]")
        end
        sanitized
      end

      def to_proc
        method(:call).to_proc
      end
    end
  end
end
