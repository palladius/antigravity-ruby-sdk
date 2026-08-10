# frozen_string_literal: true

module Antigravity
  class Hooks
    attr_reader :pre_prompt_hooks, :post_response_hooks, :pre_tool_hooks, :post_tool_hooks

    def initialize
      @pre_prompt_hooks = []
      @post_response_hooks = []
      @pre_tool_hooks = []
      @post_tool_hooks = []
    end

    def before_prompt(&block)
      @pre_prompt_hooks << block if block_given?
    end

    def after_response(&block)
      @post_response_hooks << block if block_given?
    end

    # Guard execution before a tool runs. Block can return :allow, :deny, or a hash { status: :deny, reason: "..." }
    def before_tool_call(&block)
      @pre_tool_hooks << block if block_given?
    end

    # Filter / sanitize result after a tool runs before model receives it. Block can return modified result.
    def after_tool_call(&block)
      @post_tool_hooks << block if block_given?
    end

    def run_pre_prompt(prompt_text)
      @pre_prompt_hooks.each { |hook| hook.call(prompt_text) }
    end

    def run_post_response(response)
      @post_response_hooks.each { |hook| hook.call(response) }
    end

    def run_pre_tool(tool_name, params)
      @pre_tool_hooks.each do |hook|
        result = hook.call(tool_name, params)
        if result == :deny || (result.is_a?(Hash) && result[:status] == :deny)
          reason = result.is_a?(Hash) ? result[:reason] : "Blocked by safety pre-hook policy"
          return { allowed: false, reason: reason }
        end
      end
      { allowed: true }
    end

    def run_post_tool(tool_name, params, result)
      current_result = result
      @post_tool_hooks.each do |hook|
        modified = hook.call(tool_name, params, current_result)
        current_result = modified unless modified.nil?
      end
      current_result
    end
  end
end
