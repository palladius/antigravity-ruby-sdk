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

    def execute_tool(agent, tool_name, params)
      # 1. Pre-tool Safety Policy Check
      policy_check = agent.hooks.run_pre_tool(tool_name, params)
      unless policy_check[:allowed]
        reason = policy_check[:reason]
        agent.emit_sidecar_event(:tool_blocked, tool: tool_name, params: params, reason: reason)
        return "❌ TOOL BLOCKED: #{reason}"
      end

      # 2. Execute target tool
      tool = agent.tools.find { |t| t.tool_name == tool_name }
      raw_result = tool ? tool.call(params) : "Tool #{tool_name} not found"

      # 3. Post-tool Result Masking / Filtering
      filtered_result = agent.hooks.run_post_tool(tool_name, params, raw_result)
      agent.emit_sidecar_event(:tool_executed, tool_name: tool_name, params: params, result: filtered_result)

      filtered_result
    end

    private

    def dispatch_harness_turn(agent, user_message, final_message, &block)
      thought_text = "Thinking about user prompt: #{user_message[0..30]}..."
      thought_chunk = Chunk.new(thinking: thought_text, model_id: agent.model)
      final_message.thinking += thought_text
      block.call(thought_chunk) if block_given?

      content_text = "Response from Antigravity Harness for: #{user_message}"
      content_chunk = Chunk.new(content: content_text, model_id: agent.model)
      final_message.content += content_text
      block.call(content_chunk) if block_given?
    end

    def mock_streaming_turn(agent, user_message, final_message, &block)
      # 1. Thinking step
      thought_text = "Analyzing prompt and evaluating tool invocation policies..."
      final_message.thinking += thought_text
      block.call(Chunk.new(thinking: thought_text, model_id: agent.model)) if block_given?

      # 2. Tool invocation & policy evaluation
      agent.tools.each do |tool|
        if user_message.downcase.include?(tool.tool_name.downcase)
          # Infer target path or parameters from prompt
          target_path = user_message.scan(/[\w\.\/]+/).find { |w| w.include?(".env") || w.downcase.include?("gemfile") || w.include?(".") } || "config.rb"
          params = { path: target_path, query: user_message }

          tool_call = { name: tool.tool_name, params: params }
          final_message.tool_calls << tool_call
          block.call(Chunk.new(tool_calls: [tool_call], model_id: agent.model)) if block_given?

          tool_output = execute_tool(agent, tool.tool_name, params)
          chunk_str = "\n[Tool Output for #{tool.tool_name}]: #{tool_output}\n"
          final_message.content += chunk_str
          block.call(Chunk.new(content: chunk_str, model_id: agent.model)) if block_given?
        end
      end

      # 3. Final response content streaming
      response_text = "Turn execution finished for model #{agent.model}."
      response_text.split(" ").each do |word|
        chunk_str = "#{word} "
        final_message.content += chunk_str
        block.call(Chunk.new(content: chunk_str, model_id: agent.model)) if block_given?
      end
    end
  end
end
