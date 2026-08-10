# frozen_string_literal: true

require "json"

module Antigravity
  class Client
    attr_reader :harness

    def initialize(harness: nil)
      @harness = harness || Harness.new
    end

    def send_turn(agent, user_message, &block)
      final_message = Message.new(role: :assistant, model_id: agent.model)

      if harness.running?
        dispatch_harness_turn(agent, user_message, final_message, &block)
      else
        mock_streaming_turn(agent, user_message, final_message, &block)
      end

      final_message
    end

    private

    def dispatch_harness_turn(agent, user_message, final_message, &block)
      # Thought chunk
      thought_text = "Thinking about user prompt: #{user_message[0..30]}..."
      thought_chunk = Chunk.new(thinking: thought_text, model_id: agent.model)
      final_message.thinking += thought_text
      block.call(thought_chunk) if block_given?

      # Content chunk
      content_text = "Response from Antigravity Harness for: #{user_message}"
      content_chunk = Chunk.new(content: content_text, model_id: agent.model)
      final_message.content += content_text
      block.call(content_chunk) if block_given?
    end

    def mock_streaming_turn(agent, user_message, final_message, &block)
      # 1. Thinking step
      thought_text = "Analyzing prompt and checking available tools..."
      final_message.thinking += thought_text
      block.call(Chunk.new(thinking: thought_text, model_id: agent.model)) if block_given?

      # 2. Tool invocation check
      agent.tools.each do |tool|
        if user_message.downcase.include?(tool.tool_name.downcase)
          params = { query: user_message }
          tool_call = { name: tool.tool_name, params: params }
          final_message.tool_calls << tool_call

          block.call(Chunk.new(tool_calls: [tool_call], model_id: agent.model)) if block_given?
          agent.hooks.run_tool_hooks(tool.tool_name, params)
        end
      end

      # 3. Text content streaming (RubyLLM style)
      response_text = "Hello! I am your Antigravity Agent powered by #{agent.model}. You said: '#{user_message}'."
      response_text.split(" ").each do |word|
        chunk_str = "#{word} "
        final_message.content += chunk_str
        block.call(Chunk.new(content: chunk_str, model_id: agent.model)) if block_given?
      end
    end
  end
end
