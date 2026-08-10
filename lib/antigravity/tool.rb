# frozen_string_literal: true

module Antigravity
  module Tool
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def name(val = nil, desc: nil)
        if val
          @tool_name = val.to_s
          @tool_description = desc if desc
        end
        @tool_name || self.name&.split("::")&.last&.gsub(/(.)([A-Z])/, '\1_\2')&.downcase || "custom_tool"
      end
      alias tool_name name

      def desc(val = nil)
        @tool_description = val if val
        @tool_description || ""
      end
      alias tool_description desc

      def param(name, type: :string, description: "", required: true)
        @parameters ||= {}
        @parameters[name.to_sym] = {
          type: type.to_s,
          description: description,
          required: required
        }
      end

      def parameters
        @parameters || {}
      end

      def to_json_schema
        properties = {}
        required_params = []

        parameters.each do |param_name, spec|
          properties[param_name] = {
            type: spec[:type],
            description: spec[:description]
          }
          required_params << param_name.to_s if spec[:required]
        end

        {
          name: name,
          description: desc,
          parameters: {
            type: "object",
            properties: properties,
            required: required_params
          }
        }
      end
    end

    def tool_name
      self.class.name
    end

    def to_json_schema
      self.class.to_json_schema
    end

    # Factory for dynamic Proc-based tools
    class Dynamic
      attr_reader :name, :description, :block

      def initialize(name, description: "", &block)
        @name = name.to_s
        @description = description
        @block = block
      end

      def tool_name
        @name
      end

      def call(params)
        @block.call(params)
      end

      def to_json_schema
        {
          name: @name,
          description: @description,
          parameters: {
            type: "object",
            properties: {}
          }
        }
      end
    end
  end
end
