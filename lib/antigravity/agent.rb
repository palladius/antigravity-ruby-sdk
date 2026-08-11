# frozen_string_literal: true

module Antigravity
  class Agent
    attr_accessor :model, :system_instruction, :api_key
    attr_reader :tools, :skills, :hooks, :sidecars, :client

    def initialize(model: nil, &block)
      @model = model || Antigravity.config.default_model
      @api_key = Antigravity.config.api_key
      @system_instruction = nil
      @tools = []
      @skills = []
      @sidecars = []
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

    def attach_sidecar(sidecar)
      @sidecars << sidecar
      sidecar
    end

    def attach_logger(log_target = "log/antigravity.log", level: ::Logger::INFO)
      logger_guard = Guards::AgentLogger.new(log_target, level: level)
      logger_guard.attach_to(self)
      logger_guard
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

    def before_tool_call(&block)
      hooks.before_tool_call(&block)
    end

    def after_tool_call(&block)
      hooks.after_tool_call(&block)
    end
    alias on_tool_call after_tool_call

    def emit_sidecar_event(event_type, payload = {})
      @sidecars.each { |sidecar| sidecar.emit(event_type, payload) }
    end

    def prompt(message, &block)
      emit_sidecar_event(:prompt_started, prompt: message)
      hooks.run_pre_prompt(message)

      response = client.send_turn(self, message, &block)

      hooks.run_post_response(response)
      emit_sidecar_event(:turn_completed, response: response.content, model: model)

      response
    end
    alias ask prompt
  end
end
