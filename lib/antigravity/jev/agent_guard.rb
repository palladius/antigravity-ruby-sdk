# frozen_string_literal: true

require_relative 'guardrail'

module Antigravity
  module Jev
    # Bridges the JEV guardrail into the core Antigravity hook pipeline, so
    # Antigravity::Agent and rujev share one safety brain:
    #
    #   agent = Antigravity::Agent.new
    #   Antigravity::Jev::AgentGuard.attach!(agent.hooks)
    #
    # Only shell-like tools are sent to JEV; everything else passes through
    # to the agent's own policies. Inside an agent there is no TTY to ask on,
    # so :ask verdicts are denied unless yolo: true.
    module AgentGuard
      SHELL_TOOLS  = %w[run_command shell bash exec execute_command].freeze
      COMMAND_KEYS = %w[CommandLine command_line command cmd].freeze

      module_function

      def attach!(hooks, guardrail: Guardrail.new, yolo: false)
        hooks.before_tool_call do |tool_name, params|
          command = shell_command(tool_name, params)
          next :allow unless command

          verdict(guardrail.evaluate(command), yolo)
        end
        hooks
      end

      def shell_command(tool_name, params)
        return nil unless SHELL_TOOLS.include?(tool_name.to_s)

        params = (params || {}).transform_keys(&:to_s)
        COMMAND_KEYS.map { |k| params[k] }.compact.first
      end

      def verdict(result, yolo)
        pct = (result.probability * 100).round(1)
        return :allow if result.allowed? || (result.ask? && yolo)

        label = result.ask? ? 'unsure' : 'unsafe'
        { status: :deny, reason: "🚦 JEV: #{label} (#{pct}% safe): #{result.command}" }
      end
    end
  end
end
