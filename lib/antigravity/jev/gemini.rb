# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'errors'
require_relative 'key_finder'

module Antigravity
  module Jev
    # Minimal, zero-dependency Gemini REST client used by the Jevity harness.
    #
    # - Tier names like "gemini-3.8-flash-low" map to model + thinkingLevel.
    # - Native thoughts (includeThoughts) are returned separately from the answer.
    # - Keeps multi-turn history so the REPL remembers previous turns.
    # - Falls back to `fallback_model` on any HTTP/network failure, but never
    #   silently: every failure is reported in Reply#warnings or raised.
    class Gemini
      BASE_URL    = 'https://generativelanguage.googleapis.com/v1beta/models'
      LEVEL_RE    = /\A(?<model>.+?)-(?<level>minimal|low|medium|high)\z/
      CODE_RE     = /```(?:bash|sh|shell)?[ \t]*\n(.*?)\n```/m
      THOUGHT_RE  = %r{<thought>(.*?)</thought>}m
      MAX_HISTORY = 20

      Reply = Struct.new(:thinking, :answer, :command, :model, :warnings, keyword_init: true)

      attr_reader :history, :fallback_model

      def self.resolve_api_key
        KeyFinder.lookup('GEMINI_API_KEY')
      end

      # "gemini-3.8-flash-low" -> ["gemini-3.8-flash", "low"]
      def self.parse_model(name)
        m = LEVEL_RE.match(name.to_s)
        m ? [m[:model], m[:level]] : [name.to_s, nil]
      end

      def self.parse_response(body)
        parts = body.dig('candidates', 0, 'content', 'parts') || []
        thoughts, texts = parts.partition { |p| p['thought'] }
        thinking = thoughts.map { |p| p['text'] }.join("\n").strip
        answer = texts.map { |p| p['text'] }.join.strip

        # Legacy fallback: some models still inline <thought>...</thought>
        if thinking.empty? && (tag = answer[THOUGHT_RE, 1])
          thinking = tag.strip
          answer = answer.sub(THOUGHT_RE, '').strip
        end

        Reply.new(thinking: thinking.empty? ? nil : thinking, answer: answer,
                  command: answer[CODE_RE, 1]&.strip, warnings: [])
      end

      def initialize(api_key: nil, fallback_model: nil, timeout: 30)
        @api_key = api_key || self.class.resolve_api_key
        @fallback_model = fallback_model || Jev.fallback_model
        @timeout = timeout
        @history = []
      end

      def ask(prompt, model:, system_instruction: nil)
        raise ApiError, 'GEMINI_API_KEY not found (ENV, $GIC/.env or ./.env)' if @api_key.to_s.empty?

        base, level = self.class.parse_model(model)
        user_turn = { role: 'user', parts: [{ text: prompt }] }
        payload = build_payload(@history + [user_turn], level, system_instruction)
        warnings = []

        [base, @fallback_model].compact.uniq.each do |candidate|
          code, body = safe_post(candidate, payload)
          if code == 200
            reply = self.class.parse_response(JSON.parse(body))
            remember(user_turn, reply.answer)
            reply.model = candidate
            reply.warnings = warnings
            return reply
          end
          warnings << "Gemini HTTP #{code} on #{candidate}: #{error_message(body)}"
        end

        raise ApiError, warnings.join(' | ')
      end

      def reset!
        @history.clear
      end

      private

      def build_payload(contents, level, system_instruction)
        thinking = { includeThoughts: true }
        thinking[:thinkingLevel] = level if level
        payload = { contents: contents, generationConfig: { thinkingConfig: thinking } }
        payload[:systemInstruction] = { parts: [{ text: system_instruction }] } if system_instruction
        payload
      end

      def remember(user_turn, answer)
        @history << user_turn << { role: 'model', parts: [{ text: answer.to_s }] }
        @history.shift(@history.size - MAX_HISTORY) if @history.size > MAX_HISTORY
      end

      def safe_post(model, payload)
        post(model, payload)
      rescue StandardError => e
        [0, "#{e.class}: #{e.message}"]
      end

      # Returns [status_code, body]. The key travels in a header, never in the URL.
      def post(model, payload)
        uri = URI("#{BASE_URL}/#{model}:generateContent")
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'x-goog-api-key' => @api_key)
        req.body = JSON.generate(payload)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: @timeout) do |http|
          http.request(req)
        end
        [res.code.to_i, res.body]
      end

      def error_message(body)
        JSON.parse(body.to_s).dig('error', 'message').to_s[0, 120]
      rescue JSON::ParserError
        body.to_s[0, 120]
      end
    end

    # Offline stand-in used by `rujev --mock`: no network, keyword heuristics only.
    # Never used in live mode (live failures are reported, not faked).
    class Gemini
      class Offline
        RULES = [
          [/delete.*readme|readme.*delete/i, 'rm README.md'],
          [/\b(list|show|mostra)\b.*\b(folder|directory|file|cartella)/i, 'ls -la'],
          [/move out|go up/i, 'cd ..'],
          [/\.env/i, 'cat .env']
        ].freeze

        attr_reader :history

        def initialize
          @history = []
        end

        def ask(prompt, model:, system_instruction: nil) # rubocop:disable Lint/UnusedMethodArgument
          return Reply.new(answer: '(mock) done.', model: 'offline', warnings: []) if prompt.start_with?(Harness::FOLLOWUP_MARK)

          cmd = RULES.find { |re, _| prompt.match?(re) }&.last
          Reply.new(thinking: '(mock) offline heuristic, no model call',
                    answer: cmd ? "```bash\n#{cmd}\n```" : '(mock) no command for this prompt.',
                    command: cmd, model: 'offline', warnings: [])
        end

        def reset!; end
      end
    end
  end
end
