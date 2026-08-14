# frozen_string_literal: true

require_relative 'policy/constants'

module Antigravity
  class Policy

    # ------------------------------------------------------------------
    # Rule — a single allow/deny/confirm entry in a policy.
    # ------------------------------------------------------------------
    class Rule
      attr_reader :action, :tool_name, :condition, :handler

      def initialize(action, tool_name = nil, condition: nil, handler: nil)
        @action = action
        @tool_name = tool_name
        @condition = condition
        @handler = handler
      end

      def matches?(tool, args)
        return false if @tool_name && @tool_name.to_sym != tool.to_sym
        return false if @condition && !@condition.call(name: tool, args: args)
        true
      end

      # Precedence order (higher = wins):
      # 1. Tool specificity: Specific tool > Wildcard (nil)
      # 2. Condition specificity: Has predicate > No predicate
      # 3. Action restrictiveness: Deny > Confirm > Allow
      def precedence
        specificity = @tool_name ? 1 : 0
        condition_score = @condition ? 1 : 0
        action_score = case @action
                       when :deny then 3
                       when :confirm then 2
                       when :allow then 1
                       else 0
                       end
        [specificity, condition_score, action_score]
      end
    end

    # ------------------------------------------------------------------
    # Constructor & factory methods
    # ------------------------------------------------------------------

    def initialize(&block)
      @rules = []
      @confirm_handler = nil
      instance_eval(&block) if block_given?
    end

    def self.define(&block)
      new(&block)
    end

    def self.allow_all
      new { allow_all }
    end

    def self.deny_all
      new { deny_all }
    end

    # ------------------------------------------------------------------
    # Built-in presets
    # ------------------------------------------------------------------

    # Resolve a preset by name (symbol).
    # @param name [Symbol] :cautious, :default, :turbo, :test, or :auto
    # @return [Policy]
    def self.preset(name)
      case name.to_sym
      when :cautious then cautious
      when :default  then default
      when :turbo    then turbo
      when :test     then test
      when :auto     then auto
      else
        raise ArgumentError, "Unknown preset :#{name}. Choose from: #{PRESET_NAMES.map { |n| ":#{n}" }.join(', ')}"
      end
    end

    # 🔒 Cautious — read-only free, confirm everything else, hard-deny destructive.
    # Best for: untrusted environments, production agents.
    def self.cautious
      define do
        deny_all
        READONLY_TOOLS.each { |t| allow t }
        allow :run_command, when: cmd(*SAFE_CMDS, *SAFE_GIT_CMDS)
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        deny :run_command, when: cmd(*RISKY_CMDS)
        deny :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        WRITE_TOOLS.each { |t| confirm t }
        # 📂 Sandbox dirs: always writable, even in production
        WRITE_TOOLS.each { |t| allow t, when: path(*SANDBOX_DIRS) }
        confirm :run_command
      end
    end

    # ⚖️ Default — balanced: allow reads + writes, confirm dangerous shell, protect sensitive files.
    # Best for: day-to-day development, pair programming with an agent.
    def self.default
      define do
        deny_all
        READONLY_TOOLS.each { |t| allow t }
        WRITE_TOOLS.each { |t| allow t }
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
        allow :run_command
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        confirm :run_command, when: cmd(*RISKY_CMDS)
        confirm :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
      end
    end

    # 🚀 Turbo — wide open with seatbelts: allow everything, only hard-deny catastrophic.
    # Best for: trusted dev environments, rapid prototyping.
    def self.turbo
      define do
        allow_all
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        confirm :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
      end
    end

    # 🧪 Test — permissive for test runners, but sandboxed.
    # Best for: CI, test suites, RAILS_ENV=test.
    def self.test
      define do
        allow_all
        deny :run_command, when: cmd(*CATASTROPHIC_CMDS)
        deny :run_command, when: cmd(*DESTRUCTIVE_GIT_CMDS)
        confirm :run_command, when: cmd(*RISKY_CMDS)
        WRITE_TOOLS.each { |t| confirm t, when: path(*SENSITIVE_FILES) }
      end
    end

    # 🔮 Auto — reads RAILS_ENV, RACK_ENV, or ANTIGRAVITY_ENV and picks a preset.
    # Falls back to :default if unrecognized or unset.
    def self.auto
      env = ENV['ANTIGRAVITY_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
      preset_name = ENV_MAP.fetch(env.to_s.downcase, :default)
      send(preset_name)
    end

    # ------------------------------------------------------------------
    # DSL methods
    # ------------------------------------------------------------------

    def allow(tool_name = nil, **kwargs)
      @rules << Rule.new(:allow, tool_name, condition: kwargs[:when])
    end

    def deny(tool_name = nil, **kwargs)
      @rules << Rule.new(:deny, tool_name, condition: kwargs[:when])
    end

    def confirm(tool_name = nil, **kwargs, &block)
      @rules << Rule.new(:confirm, tool_name, condition: kwargs[:when], handler: block)
    end

    def allow_all
      allow(nil)
    end

    def deny_all
      deny(nil)
    end

    def on_confirm(&block)
      @confirm_handler = block
    end

    # ------------------------------------------------------------------
    # Predicate helpers
    # ------------------------------------------------------------------

    def cmd(*patterns)
      ->(ctx) do
        args = ctx[:args]
        cmd_arg = args[:command_line] || args['command_line'] || args[:CommandLine] || args['CommandLine']
        return false unless cmd_arg

        cmd_arg = cmd_arg.to_s
        patterns.any? { |p| cmd_arg.include?(p.to_s) }
      end
    end

    def path(*globs)
      ->(ctx) do
        args = ctx[:args]
        path_arg = args[:path] || args['path'] ||
                   args[:file] || args['file'] ||
                   args[:target] || args['target'] ||
                   args[:file_path] || args['file_path'] ||
                   args[:target_file] || args['target_file']
        return false unless path_arg

        path_arg = path_arg.to_s
        globs.any? { |g| File.fnmatch?(g.to_s, path_arg) }
      end
    end

    def args_match(**matchers)
      ->(ctx) do
        args = ctx[:args]
        matchers.any? do |k, v|
          val = args[k.to_sym] || args[k.to_s]
          val && v.match?(val.to_s)
        end
      end
    end

    # ------------------------------------------------------------------
    # Evaluation engine
    # ------------------------------------------------------------------

    def evaluate(tool_name, args = {})
      matching_rules = @rules.select { |r| r.matches?(tool_name, args) }
      best_rule = matching_rules.max_by(&:precedence)

      if best_rule
        if best_rule.action == :confirm
          handler = best_rule.handler || @confirm_handler
          if handler
            ctx = { name: tool_name, args: args }
            result = handler.call(ctx)
            { status: result ? :allow : :deny }
          else
            { status: :deny }
          end
        elsif best_rule.action == :deny
          { status: :deny, reason: "Denied by policy" }
        else
          { status: :allow }
        end
      else
        { status: :deny } # Default to deny if no rules match
      end
    end
  end
end
