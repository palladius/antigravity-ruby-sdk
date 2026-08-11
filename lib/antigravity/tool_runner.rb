# frozen_string_literal: true

require 'json'

module Antigravity
  # Registers, resolves, and executes custom tools for agent callbacks.
  # Tools are invoked by the harness when the model decides to call them.
  class ToolRunner < Base
    def initialize
      @tools = {}
    end

    # Register a tool (Tool::Dynamic or any Tool subclass)
    def register(tool)
      name = tool.respond_to?(:tool_name) ? tool.tool_name : tool.to_s
      raise ToolError, "Tool '#{name}' is already registered" if @tools.key?(name)

      @tools[name] = tool
    end

    # Check if a tool is registered
    def registered?(name)
      @tools.key?(name.to_s)
    end

    # Execute a tool by name with keyword args.
    # Returns the result or a { error: "..." } hash on failure.
    def execute(name, **kwargs)
      tool = @tools[name.to_s]
      raise ToolNotFoundError, "Tool '#{name}' not found" unless tool

      tool.call(**kwargs)
    rescue ToolNotFoundError
      raise
    rescue => e
      { error: e.message }
    end

    # Generate harness-compatible tool definitions for HarnessConfig
    def to_harness_tools
      @tools.values.map do |tool|
        schema = tool.to_json_schema
        {
          name: schema[:name],
          description: schema[:description],
          parameters_json_schema: JSON.generate(schema[:parameters])
        }
      end
    end

    def size
      @tools.size
    end

    def empty?
      @tools.empty?
    end
  end
end
