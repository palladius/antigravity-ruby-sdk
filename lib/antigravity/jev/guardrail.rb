# frozen_string_literal: true

require 'open3'
require_relative 'client'
require_relative 'telemetry'

module Antigravity
  module Jev
    class Guardrail
      DEFAULT_ALLOW_THRESHOLD = 0.80
      DEFAULT_DENY_THRESHOLD = 0.40

      class GuardrailResult
        attr_reader :command, :verdict, :probability, :latency_ms, :response

        def initialize(command:, verdict:, probability:, latency_ms:, response: nil)
          @command = command
          @verdict = verdict
          @probability = probability
          @latency_ms = latency_ms
          @response = response
        end

        def allowed?
          @verdict == :allow
        end

        def denied?
          @verdict == :deny
        end

        def ask?
          @verdict == :ask
        end
      end

      attr_reader :client, :allow_threshold, :deny_threshold

      def initialize(client: nil, allow_threshold: nil, deny_threshold: nil)
        @client = client || Jev.client
        @allow_threshold = allow_threshold || Jev.allow_threshold
        @deny_threshold = deny_threshold || Jev.deny_threshold
      end

      def evaluate(command)
        instructions = 'Is executing this shell command safe, non-destructive, and free of secret/credential exposure or destructive system modification?'
        prob, resp = @client.noul(instructions, state: command)

        p_val = prob || 0.50
        verdict = if p_val >= @allow_threshold
                    :allow
                  elsif p_val < @deny_threshold
                    :deny
                  else
                    :ask
                  end

        GuardrailResult.new(
          command: command,
          verdict: verdict,
          probability: p_val,
          latency_ms: resp&.latency_ms || 0.0,
          response: resp
        )
      end

      def execute_guarded(command, input_stream: $stdin, output_stream: $stdout, yolo: false, &runner)
        result = evaluate(command)

        line = Telemetry.format_command_verdict(
          result.verdict,
          command,
          latency_ms: result.latency_ms,
          probability: result.probability,
          color: output_stream.respond_to?(:tty?) && output_stream.tty?
        )
        output_stream.puts line

        case result.verdict
        when :allow
          output = run_command(command, &runner)
          { executed: true, status: :allowed, output: output, verdict: :allow, result: result }
        when :deny
          { executed: false, status: :blocked, verdict: :deny, result: result }
        when :ask
          if yolo
            output = run_command(command, &runner)
            { executed: true, status: :allowed_by_yolo, output: output, verdict: :ask, result: result }
          else
            output_stream.print 'Execute this command? [y/N]: '
            choice = input_stream.gets&.strip&.downcase
            if %w[y yes].include?(choice)
              output = run_command(command, &runner)
              { executed: true, status: :allowed_by_user, output: output, verdict: :ask, result: result }
            else
              output_stream.puts 'Execution cancelled.' if output_stream.respond_to?(:puts)
              { executed: false, status: :rejected_by_user, verdict: :ask, result: result }
            end
          end
        end
      end

      private

      def run_command(command, &runner)
        # Absolute failsafe protection: NEVER execute catastrophic system wipes under ANY circumstances
        if command =~ %r{\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f?[a-zA-Z]*\s+(/|~|/\*)|--no-preserve-root)}
          raise GuardrailBlockedError, "Execution of catastrophic command is strictly prohibited: #{command}"
        end

        if runner
          runner.call(command)
        else
          stdout_and_stderr, _status = Open3.capture2e(command)
          stdout_and_stderr
        end
      end
    end
  end
end
