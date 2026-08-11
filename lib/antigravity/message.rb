# frozen_string_literal: true

module Antigravity
  class Message
    include Emojifiable

    attr_accessor :role, :content, :thinking, :tool_calls, :model_id, :tokens

    def initialize(role: :assistant, content: "", thinking: "", tool_calls: [], model_id: nil)
      @role = role
      @content = content
      @thinking = thinking
      @tool_calls = tool_calls
      @model_id = model_id
      @tokens = { input: 0, output: 0 }
    end
  end

  class Chunk < Message
    def initialize(role: :assistant, content: "", thinking: "", tool_calls: [], model_id: nil)
      super(role: role, content: content, thinking: thinking, tool_calls: tool_calls, model_id: model_id)
    end
  end
end
