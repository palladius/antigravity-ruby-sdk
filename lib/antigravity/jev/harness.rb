# frozen_string_literal: true

require 'net/http'
require 'json'
require 'open3'
require 'uri'
require_relative 'client'
require_relative 'router'
require_relative 'guardrail'
require_relative 'telemetry'

module Antigravity
  module Jev
    class Harness
      GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

      attr_reader :client, :router, :guardrail, :output, :input

      def initialize(client: nil, router: nil, guardrail: nil, output: $stdout, input: $stdin)
        @client = client || Jev.client
        @router = router || Router.new(client: @client)
        @guardrail = guardrail || Guardrail.new(client: @client)
        @output = output
        @input = input
      end

      def process(user_input)
        text = user_input.to_s.strip
        return { error: 'Empty input' } if text.empty?

        # 1. Routing step (Fast visual telemetry)
        route_res = @router.route(text)
        routing_line = Telemetry.format_routing(
          route_res.complexity,
          route_res.model,
          latency_ms: route_res.latency_ms,
          confidence: route_res.confidence,
          color: @output.respond_to?(:tty?) && @output.tty?
        )
        @output.puts routing_line

        # 2. Determine if it's natural language or direct shell command
        cmd = if direct_command?(text)
                text
              else
                translate_to_command(text, model: route_res.model)
              end

        # 3. Guardrail evaluation & guarded execution
        exec_res = @guardrail.execute_guarded(cmd, input_stream: @input, output_stream: @output) do |command_to_run|
          run_system_command(command_to_run)
        end

        exec_res.merge(command: cmd, route: route_res)
      end

      def translate_to_command(prompt, model: 'gemini-2.5-flash')
        api_key = ENV['GEMINI_API_KEY']
        if api_key && !api_key.empty?
          begin
            cmd = query_gemini_for_command(prompt, model: model, api_key: api_key)
            return cmd if cmd && !cmd.empty?
          rescue StandardError
            # Fall back to heuristic if network/API error
          end
        end

        heuristic_command(prompt)
      end

      def run_system_command(cmd)
        stdout_and_stderr, = Open3.capture2e(cmd)
        @output.puts stdout_and_stderr unless stdout_and_stderr.empty?
        stdout_and_stderr
      end

      private

      def direct_command?(text)
        first_word = text.split(/\s+/).first.to_s.downcase
        %w[ls cat rm git pwd echo touch mkdir cd find grep ruby bundle which head tail cp mv].include?(first_word)
      end

      def query_gemini_for_command(prompt, model:, api_key:)
        uri = URI("#{GEMINI_BASE_URL}/#{model}:generateContent?key=#{api_key}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 8
        http.read_timeout = 8

        system_instruction = 'You are a Unix command assistant. Given a user request, return EXACTLY one single bash command to fulfill it. Return ONLY the raw shell command, no backticks, no markdown, no comments, no explanation.'
        payload = {
          contents: [
            {
              role: 'user',
              parts: [{ text: "#{system_instruction}\n\nUser request: #{prompt}" }]
            }
          ]
        }

        req = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
        req.body = JSON.generate(payload)

        res = http.request(req)
        return nil unless res.is_a?(Net::HTTPSuccess)

        parsed = JSON.parse(res.body)
        raw_cmd = parsed.dig('candidates', 0, 'content', 'parts', 0, 'text')&.strip
        # Clean potential markdown code blocks
        raw_cmd&.gsub(/^```[a-z]*\n?/, '')&.gsub(/```$/, '')&.strip
      end

      def heuristic_command(prompt)
        p = prompt.downcase
        if p.include?('delete') && p.include?('readme')
          'rm README.md'
        elsif p.include?('delete') || p.include?('remove')
          target = prompt.scan(/[\w.-]+/).last || 'file.tmp'
          "rm #{target}"
        elsif p.include?('list') || (p.include?('show') && (p.include?('folder') || p.include?('directory')))
          'ls -la'
        elsif p.include?('move out') || p.include?('go up')
          'cd ..'
        elsif p.include?('.env')
          'cat .env'
        elsif p.include?('readme')
          'cat README.md'
        else
          "echo 'Interpreted: #{prompt}'"
        end
      end
    end
  end
end
