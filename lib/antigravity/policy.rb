# frozen_string_literal: true

module Antigravity
  class Policy
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

      # Precedence order:
      # Specific > Wildcard
      # Deny > Confirm > Allow
      def precedence
        specificity = @tool_name ? 1 : 0
        action_score = case @action
                       when :deny then 3
                       when :confirm then 2
                       when :allow then 1
                       else 0
                       end
        [specificity, action_score]
      end
    end

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
