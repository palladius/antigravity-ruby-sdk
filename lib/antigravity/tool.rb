# frozen_string_literal: true

module Antigravity
  class Tool < Base
    class << self
      def inherited(subclass)
        super
        subclass.extend(ClassMethods)
      end

      # Factory method: define a tool inline with a block.
      #   Tool.define(:name, desc: '...', params: { city: { type: :string } }) { |city:| ... }
      def define(name, desc: '', params: {}, &block)
        Dynamic.new(name, description: desc, params: params, &block)
      end
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
    class Dynamic < Tool
      attr_reader :block, :params

      def initialize(name, description: '', params: {}, &block)
        super()
        @dynamic_name = name.to_s
        @dynamic_description = description
        @params = params
        @block = block
      end

      def tool_name
        @dynamic_name
      end

      def call(params = nil, **kwargs)
        return nil unless @block

        if params && kwargs.empty?
          # Old-style: tool.call({key: value})
          @block.call(params)
        else
          # New-style: tool.call(key: value)
          @block.call(**kwargs)
        end
      end

      def to_json_schema
        properties = {}
        required_params = []

        @params.each do |param_name, spec|
          properties[param_name] = {
            type: (spec[:type] || :string).to_s,
            description: spec[:description] || spec[:desc] || ''
          }
          required_params << param_name.to_s unless spec[:required] == false
        end

        {
          name: @dynamic_name,
          description: @dynamic_description,
          parameters: {
            type: 'object',
            properties: properties,
            required: required_params
          }
        }
      end
    end
  end
end
