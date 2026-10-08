# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'errors'
require_relative 'key_finder'

module Antigravity
  module Jev
    class Client
      ENDPOINT = 'https://api.typesafe.ai/v1/systemone'

      attr_reader :api_key, :timeout

      def initialize(api_key: nil, mock: false, timeout: 5)
        @mock = mock
        @timeout = timeout
        @api_key = api_key || (mock ? nil : self.class.resolve_api_key)

        if !@mock && (@api_key.nil? || @api_key.empty?)
          raise AuthenticationError,
                'TypeSafe JEV API key (JEV_API_KEY_RUJEV) not found in ENV or GIC config'
        end

        @mock_handler = nil
      end

      def mock?
        @mock
      end

      def set_mock_handler(&block)
        @mock_handler = block
      end

      # Strictly JEV_API_KEY_RUJEV: ENV, then $GIC/.env (default ~/git/gic), then ./.env.
      # Read-only: never writes any .env file.
      def self.resolve_api_key
        KeyFinder.lookup('JEV_API_KEY_RUJEV')
      end

      def systemone(state:, questions:, model: 'jev-latest')
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if mock?
          data = if @mock_handler
                   answers = @mock_handler.call(state, questions)
                   { 'model' => model, 'answers' => answers,
                     'usage' => { 'input_tokens' => 50, 'output_tokens' => 10 } }
                 else
                   default_mock_response(questions)
                 end
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          latency = ((t1 - t0) * 1000.0).round(2)
          return Response.new(data: data, latency_ms: latency)
        end

        uri = URI(ENDPOINT)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        req = Net::HTTP::Post.new(uri.path, {
                                    'Content-Type' => 'application/json',
                                    'Authorization' => "Bearer #{@api_key}"
                                  })

        payload = {
          model: model,
          state: state,
          questions: questions
        }
        req.body = JSON.generate(payload)

        begin
          res = http.request(req)
        rescue *NETWORK_ERRORS => e
          raise NetworkError, "JEV (System One) unreachable: #{e.class} (timeout #{@timeout}s)"
        end
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        latency = ((t1 - t0) * 1000.0).round(2)

        raise ApiError, "JEV API request failed (#{res.code}): #{res.body}" unless res.is_a?(Net::HTTPSuccess)

        data = JSON.parse(res.body)
        Response.new(data: data, latency_ms: latency)
      end

      def noul(instructions, state: nil, key: :verdict)
        state_str = state.is_a?(Hash) ? JSON.generate(state) : state.to_s
        questions = {
          key => {
            type: 'noul',
            instructions: instructions
          }
        }
        resp = systemone(state: state_str, questions: questions)
        val = resp.noul(key)
        val = resp.noul(resp.answers.keys.first) if val.nil? && resp.answers.size == 1
        [val, resp]
      end

      def choice(criteria, state: nil, instructions: nil, key: :category)
        state_str = state.is_a?(Hash) ? JSON.generate(state) : state.to_s
        q = { type: 'choice', criteria: criteria }
        q[:instructions] = instructions if instructions
        resp = systemone(state: state_str, questions: { key => q })
        c = resp.choice(key)
        conf = resp.confidence(key)
        if c.nil? && resp.answers.size == 1
          single_key = resp.answers.keys.first
          c = resp.choice(single_key)
          conf = resp.confidence(single_key)
        end
        [c, conf, resp]
      end

      def score(rubric, state: nil, key: :grade)
        state_str = state.is_a?(Hash) ? JSON.generate(state) : state.to_s
        q = { type: 'score', rubric: rubric }
        resp = systemone(state: state_str, questions: { key => q })
        s = resp.score(key)
        conf = resp.confidence(key)
        if s.nil? && resp.answers.size == 1
          single_key = resp.answers.keys.first
          s = resp.score(single_key)
          conf = resp.confidence(single_key)
        end
        [s, conf, resp]
      end

      private

      def default_mock_response(questions)
        answers = {}
        questions.each do |k, v|
          type = v[:type] || v['type']
          answers[k.to_s] = case type.to_s
                            when 'noul'
                              { 'type' => 'noul', 'noul' => 0.95 }
                            when 'choice'
                              criteria = v[:criteria] || v['criteria'] || {}
                              first_choice = criteria.keys.first.to_s
                              { 'type' => 'choice', 'choice' => first_choice, 'confidence' => 0.90 }
                            when 'score'
                              { 'type' => 'score', 'score' => 5.0, 'confidence' => 0.85 }
                            else
                              { 'type' => 'unknown' }
                            end
        end
        { 'model' => 'jev-mock', 'answers' => answers, 'usage' => {} }
      end
    end
  end
end
