# frozen_string_literal: true

module Antigravity
  # Represents a response message from the agent.
  # Mirrors Python SDK's ChatResponse with metadata.
  class Message < Base
    attr_accessor :role, :content, :thinking, :tool_calls, :model_id, :tokens,
                  :steps, :tool_calls_count, :usage, :delta

    def initialize(role: :assistant, content: '', thinking: '', tool_calls: [],
                   model_id: nil, steps: [], tool_calls_count: 0, usage: nil,
                   delta: false)
      @role = role
      @content = content
      @thinking = thinking
      @tool_calls = tool_calls
      @model_id = model_id
      @tokens = { input: 0, output: 0 }
      @steps = steps
      @tool_calls_count = tool_calls_count
      @usage = usage || { prompt_token_count: 0, candidates_token_count: 0, total_token_count: 0 }
      @delta = delta
    end

    # Is this a streaming delta (partial) or a complete response?
    def delta?
      @delta
    end

    # Does this message/chunk contain thinking content?
    def thinking?
      @thinking.is_a?(String) && !@thinking.empty?
    end

    # Does this message/chunk contain visible content?
    def content?
      @content.is_a?(String) && !@content.empty?
    end
  end

  # Backward-compatible alias for streaming chunks.
  # Chunks carry either thinking or content deltas (or both).
  class Chunk < Message
    def initialize(**kwargs)
      super(**kwargs, delta: true)
    end
  end
end
