# frozen_string_literal: true

module Antigravity
  class Hooks
    attr_reader :pre_hooks, :post_hooks, :tool_hooks

    def initialize
      @pre_hooks = []
      @post_hooks = []
      @tool_hooks = []
    end

    def before_prompt(&block)
      @pre_hooks << block if block_given?
    end

    def after_response(&block)
      @post_hooks << block if block_given?
    end

    def on_tool_call(&block)
      @tool_hooks << block if block_given?
    end

    def run_pre_hooks(prompt_text)
      @pre_hooks.each { |hook| hook.call(prompt_text) }
    end

    def run_post_hooks(response)
      @post_hooks.each { |hook| hook.call(response) }
    end

    def run_tool_hooks(tool_name, params)
      @tool_hooks.each { |hook| hook.call(tool_name, params) }
    end
  end
end
