# frozen_string_literal: true

module Antigravity
  class Agent
    attr_accessor :model, :system_instruction, :api_key
    attr_reader :tools, :skills, :hooks, :client

    def initialize(model: nil, &block)
      @model = model || Antigravity.config.default_model
      @api_key = Antigravity.config.api_key
      @system_instruction = nil
      @tools = []
      @skills = []
      @hooks = Hooks.new
      @client = Client.new

      yield(self) if block_given?
    end

    def register_tool(tool_or_name = nil, description: "", &block)
      if block_given? && tool_or_name
        tool = Tool::Dynamic.new(tool_or_name, description: description, &block)
      elsif tool_or_name.respond_to?(:to_json_schema)
        tool = tool_or_name
      else
        raise ArgumentError, "Invalid tool definition"
      end
      @tools << tool
      tool
    end

    def load_skill(skill_path)
      skill = Skill.load(skill_path)
      @skills << skill
      skill
    end

    def before_prompt(&block)
      hooks.before_prompt(&block)
    end

    def after_response(&block)
      hooks.after_response(&block)
    end

    def on_tool_call(&block)
      hooks.on_tool_call(&block)
    end

    def prompt(message, &block)
      hooks.run_pre_hooks(message)
      response = client.send_turn(self, message, &block)
      hooks.run_post_hooks(response)
      response
    end
    alias ask prompt
  end
end
