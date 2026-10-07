# frozen_string_literal: true

require 'open3'
require_relative 'client'
require_relative 'router'
require_relative 'guardrail'
require_relative 'telemetry'
require_relative 'renderer'
require_relative 'gemini'

module Antigravity
  module Jev
    # Jevity mini-harness: route (JEV) -> think/answer (Gemini) -> guard (JEV) -> run -> observe.
    #
    # Natural-language prompts get a real model answer. If the model proposes
    # a shell command, JEV guards it; its output is fed back to the model so it
    # can finish the answer (up to MAX_STEPS commands per prompt).
    class Harness
      MAX_STEPS     = 3
      MAX_OBSERVED  = 4_000 # chars of command output fed back to the model
      FOLLOWUP_MARK = '[command output]'
      DIRECT_COMMANDS = %w[ls cat rm git pwd echo touch mkdir cd find grep ruby bundle which head tail cp mv].freeze

      attr_reader :client, :router, :guardrail, :output, :input, :gemini, :renderer

      def initialize(client: nil, router: nil, guardrail: nil, output: $stdout, input: $stdin,
                     gemini: nil, renderer: nil)
        @client = client || Jev.client
        @router = router || Router.new(client: @client)
        @guardrail = guardrail || Guardrail.new(client: @client)
        @output = output
        @input = input
        @gemini = gemini || (@client.mock? ? Gemini::Offline.new : Gemini.new)
        @renderer = renderer || Renderer.new(output: output)
      end

      def process(user_input, yolo: false)
        text = user_input.to_s.strip
        return { error: 'Empty input', status: :error } if text.empty?

        route_res = route(text)
        return guarded(text, yolo).merge(route: route_res) if direct_command?(text)

        agent_loop(text, route_res, yolo)
      end

      # Used by `jevity ask`: show thinking/answer, return the proposed command (not executed).
      def translate_to_command(prompt, model:)
        ask_model(prompt, model)&.command
      end

      def run_system_command(cmd)
        stdout_and_stderr, = Open3.capture2e(cmd)
        @output.puts stdout_and_stderr unless stdout_and_stderr.empty?
        stdout_and_stderr
      end

      private

      def route(text)
        res = @router.route(text)
        @output.puts Telemetry.format_routing(res.complexity, res.model, latency_ms: res.latency_ms,
                                                                        confidence: res.confidence, color: tty?)
        res
      end

      def agent_loop(text, route_res, yolo)
        prompt = text
        executed = false
        last = nil

        MAX_STEPS.times do
          reply = ask_model(prompt, route_res.model)
          return { executed: executed, status: :error, route: route_res } unless reply
          return { executed: executed, status: :answered, command: last, route: route_res, reply: reply } unless reply.command

          last = reply.command
          res = guarded(last, yolo)
          return res.merge(command: last, route: route_res) unless res[:executed]

          executed = true
          prompt = followup_prompt(last, res[:output])
        end

        { executed: executed, status: :max_steps, command: last, route: route_res }
      end

      def ask_model(prompt, model)
        reply = @gemini.ask(prompt, model: model, system_instruction: system_instruction)
        reply.warnings.to_a.each { |w| @renderer.warning(w) }
        @renderer.thinking(reply.thinking)
        @renderer.answer(reply.answer)
        reply
      rescue ApiError => e
        @renderer.warning("Gemini error: #{e.message}")
        nil
      end

      def guarded(cmd, yolo)
        @guardrail.execute_guarded(cmd, input_stream: @input, output_stream: @output, yolo: yolo) do |c|
          run_system_command(c)
        end
      end

      def followup_prompt(cmd, out)
        "#{FOLLOWUP_MARK} `#{cmd}` returned:\n#{out.to_s[0, MAX_OBSERVED]}\n\n" \
          'Use this to answer my original request. Propose another command only if strictly needed.'
      end

      def system_instruction
        files = Dir.children('.').sort.first(40).join(', ')
        <<~PROMPT
          You are Jevity, a concise AI assistant in the developer's terminal.
          Workspace: #{Dir.pwd}
          Top-level entries: #{files}
          Answer in the user's language. If running ONE shell command would help answer or
          fulfil the request, include it in a ```bash fenced block; JEV will safety-check it
          before it runs and you will receive its output. Never wrap prose in <thought> tags.
        PROMPT
      rescue SystemCallError
        'You are Jevity, a concise AI assistant in the developer terminal.'
      end

      def direct_command?(text)
        DIRECT_COMMANDS.include?(text.split(/\s+/).first.to_s.downcase)
      end

      def tty?
        @output.respond_to?(:tty?) && @output.tty?
      end
    end
  end
end
