# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'errors'
require_relative 'key_finder'
require_relative 'sse_parser'

module Antigravity
  module Jev
    # Minimal, zero-dependency Gemini REST client used by the Jevity harness.
    #
    # - Tier names like "gemini-3.8-flash-low" map to model + thinkingLevel.
    # - Native thoughts (includeThoughts) are returned separately from the answer.
    # - Keeps multi-turn history so the REPL remembers previous turns.
    # - Pass a block to #ask to STREAM (SSE): it yields (:thought|:text|:warning, delta)
    #   as soon as tokens arrive, with a short first-byte timeout.
    # - Falls back along the `fallback_model` chain on any HTTP/network failure,
    #   never silently: every failure is reported (warnings / yielded / raised).
    class Gemini
      BASE_URL    = 'https://generativelanguage.googleapis.com/v1beta/models'
      LEVEL_RE    = /\A(?<model>.+?)-(?<level>minimal|low|medium|high)\z/
      CODE_RE     = /```(?:bash|sh|shell)?(?<final>[ \t]+final)?[ \t]*\n(?<cmd>.*?)\n```/m
      THOUGHT_RE  = %r{<thought>(.*?)</thought>}m
      MAX_HISTORY = 20

      Reply = Struct.new(:thinking, :answer, :command, :final, :model, :warnings, keyword_init: true)

      attr_reader :history, :timeout, :first_byte_timeout, :degraded

      def self.resolve_api_key
        KeyFinder.lookup('GEMINI_API_KEY')
      end

      # "gemini-3.8-flash-low" -> ["gemini-3.8-flash", "low"]
      def self.parse_model(name)
        m = LEVEL_RE.match(name.to_s)
        m ? [m[:model], m[:level]] : [name.to_s, nil]
      end

      def self.parse_response(body)
        parse_parts(body.dig('candidates', 0, 'content', 'parts') || [])
      end

      def self.parse_parts(parts)
        thoughts, texts = parts.partition { |p| p['thought'] }
        thinking = thoughts.map { |p| p['text'] }.join("\n").strip
        answer = texts.map { |p| p['text'] }.join.strip

        # Legacy fallback: some models still inline <thought>...</thought>
        if thinking.empty? && (tag = answer[THOUGHT_RE, 1])
          thinking = tag.strip
          answer = answer.sub(THOUGHT_RE, '').strip
        end

        code = CODE_RE.match(answer)
        Reply.new(thinking: thinking.empty? ? nil : thinking, answer: answer,
                  command: code && code[:cmd].strip, final: !code&.[](:final).nil?, warnings: [])
      end

      def initialize(api_key: nil, fallback_model: nil, timeout: nil, first_byte_timeout: nil)
        @api_key = api_key || self.class.resolve_api_key
        @fallbacks = (fallback_model || Jev.fallback_model).to_s.split(',').map(&:strip).reject(&:empty?)
        @timeout = timeout || Jev.gemini_timeout
        @first_byte_timeout = first_byte_timeout || Jev.first_byte_timeout
        @history = []
        @degraded = []
      end

      def fallback_model
        @fallbacks.first
      end

      def ask(prompt, model:, system_instruction: nil, &on_part)
        raise ApiError, 'GEMINI_API_KEY not found (ENV, $GIC/.env or ./.env)' if @api_key.to_s.empty?

        base, level = self.class.parse_model(model)
        user_turn = { role: 'user', parts: [{ text: prompt }] }
        payload = build_payload(@history + [user_turn], level, system_instruction)
        warnings = []

        candidates(base).each do |candidate|
          code, body = attempt(candidate, payload, &on_part)
          return success(candidate, body, user_turn, warnings, streamed: !on_part.nil?) if code == 200

          @degraded |= [candidate]
          msg = "Gemini HTTP #{code} on #{candidate}: #{error_message(body)}"
          warnings << msg
          on_part&.call(:warning, msg)
        end

        raise ApiError, warnings.join(' | ')
      end

      def reset!
        @history.clear
        @degraded.clear
      end

      private

      def attempt(candidate, payload, &on_part)
        on_part ? stream(candidate, payload, &on_part) : post(candidate, payload)
      rescue StandardError => e
        [0, "#{e.class}: #{e.message}"]
      end

      def success(candidate, body, user_turn, warnings, streamed:)
        @degraded.delete(candidate)
        reply = streamed ? self.class.parse_parts(body) : self.class.parse_response(JSON.parse(body))
        remember(user_turn, reply.answer)
        reply.model = candidate
        reply.warnings = warnings
        reply
      end

      # Healthy models first (routed, then fallback chain); models that already
      # failed this session go last, as a last resort.
      def candidates(base)
        all = [base, *@fallbacks].compact.uniq
        healthy, sick = all.partition { |m| !@degraded.include?(m) }
        healthy + sick
      end

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

      def request_for(uri, payload)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'x-goog-api-key' => @api_key)
        req.body = JSON.generate(payload)
        req
      end

      # Returns [status_code, body]. The key travels in a header, never in the URL.
      def post(model, payload)
        uri = URI("#{BASE_URL}/#{model}:generateContent")
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: @timeout) do |http|
          http.request(request_for(uri, payload))
        end
        [res.code.to_i, res.body]
      end

      # SSE streaming. Yields (:thought|:text, delta) live and returns
      # [200, merged_parts] or [status, error_body].
      # Short timeout until the first chunk, then @timeout between chunks.
      def stream(model, payload, &on_part)
        uri = URI("#{BASE_URL}/#{model}:streamGenerateContent?alt=sse")
        acc = { thought: +'', text: +'' }
        parser = SseParser.new { |event| stream_event(event, acc, &on_part) }

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: @first_byte_timeout) do |http|
          http.request(request_for(uri, payload)) do |res|
            return [res.code.to_i, res.read_body] unless res.code == '200'

            res.read_body do |chunk|
              http.read_timeout = @timeout
              parser.feed(chunk)
            end
          end
        end
        [200, [{ 'thought' => true, 'text' => acc[:thought] }, { 'text' => acc[:text] }]]
      end

      def stream_event(event, acc, &on_part)
        (event.dig('candidates', 0, 'content', 'parts') || []).each do |part|
          next unless part['text']

          kind = part['thought'] ? :thought : :text
          acc[kind] << part['text']
          on_part.call(kind, part['text'])
        end
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

        def ask(prompt, model:, system_instruction: nil, &on_part) # rubocop:disable Lint/UnusedMethodArgument
          reply = offline_reply(prompt)
          on_part&.call(:thought, "#{reply.thinking}\n") if reply.thinking
          on_part&.call(:text, reply.answer)
          reply
        end

        def reset!; end

        private

        def offline_reply(prompt)
          return Reply.new(answer: '(mock) done.', model: 'offline', warnings: []) if prompt.start_with?(Harness::FOLLOWUP_MARK)

          cmd = RULES.find { |re, _| prompt.match?(re) }&.last
          Reply.new(thinking: '(mock) offline heuristic, no model call',
                    answer: cmd ? "```bash\n#{cmd}\n```" : '(mock) no command for this prompt.',
                    command: cmd, model: 'offline', warnings: [])
        end
      end
    end
  end
end
