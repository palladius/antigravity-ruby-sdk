# frozen_string_literal: true

module Antigravity
  module Tool
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def tool_name(name = nil)
        @tool_name = name if name
        @tool_name || self.name.split("::").last.gsub(/(.)([A-Z])/, '\1_\2').downcase
      end

      def tool_description(desc = nil)
        @tool_description = desc if desc
        @tool_description || ""
      end

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
          name: tool_name,
          description: tool_description,
          parameters: {
            type: "object",
            properties: properties,
            required: required_params
          }
        }
      end
    end

    def tool_name
      self.class.tool_name
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
