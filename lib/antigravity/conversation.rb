# frozen_string_literal: true

require 'json'
require 'securerandom'

module Antigravity
  # Manages a multi-turn conversation with the harness over WebSocket.
  # Handles the event loop: send InputEvent, receive OutputEvents, dispatch tools.
  #
  # Mirrors Python SDK's Conversation class:
  #   - history, turn_count, conversation_id
  #   - last_turn_usage, total_usage
  class Conversation
    attr_reader :conversation_id, :history, :turn_count, :total_usage, :last_turn_usage

    def initialize(ws_client:, tool_runner: nil)
      @ws = ws_client
      @tool_runner = tool_runner || ToolRunner.new
      @conversation_id = nil
      @history = []
      @turn_count = 0
      @total_usage = empty_usage
      @last_turn_usage = nil
      @initialized = false
    end

    # Initialize the conversation session with the harness.
    # Sends InitializeConversationEvent (protobuf JSON format), receives response.
    def initialize_session!(harness_config:)
      # harness_config IS the InitializeConversationEvent JSON:
      # { config: { models: [...], workspaces: [...], ... } }
      @ws.send_json(harness_config)

      # Wait for InitializeConversationResponse
      msg = @ws.receive_json(timeout: 30)
      raise ProtocolError, 'No response to InitializeConversationEvent' unless msg

      if (init_resp = msg[:initializeConversationResponse])
        @conversation_id = init_resp[:cascadeId]
        @initialized = true
      else
        # Some harness versions may wrap differently
        @conversation_id = msg[:cascadeId] || msg.dig(:config, :cascadeId) || SecureRandom.uuid
        @initialized = true
      end

      self
    end

    # Send a user message and collect the full response.
    # Yields streaming chunks if a block is given.
    #
    # @param prompt [String] user message
    # @return [Message] the complete response
    def chat(prompt, &block)
      raise ProtocolError, 'Session not initialized' unless @initialized

      @turn_count += 1
      @last_turn_usage = empty_usage

      # Send user input (protobuf InputEvent with user_input string field)
      input_event = {
        userInput: prompt
      }
      @ws.send_json(input_event)

      # Collect response
      collect_response(&block)
    end

    def initialized?
      @initialized
    end

    # Generate a session summary hash (mirrors Python's metadata)
    def session_summary(model: nil)
      {
        conversation_id: @conversation_id,
        turn_count: @turn_count,
        total_tokens: @total_usage[:total_token_count],
        prompt_tokens: @total_usage[:prompt_token_count],
        candidates_tokens: @total_usage[:candidates_token_count],
        model: model
      }
    end

    private

    def collect_response(&block)
      text_parts = []
      thinking_parts = []
      steps = []
      tool_calls_count = 0
      finished = false

      @ws.each_message(timeout: 120) do |msg|
        if (step = msg[:stepUpdate])
          step_record = parse_step(step)
          steps << step_record

          # Text delta — stream it (only from model, not user echo)
          is_model_step = step[:source].to_s =~ /MODEL|model|3/
          if step[:textDelta] && !step[:textDelta].empty? && is_model_step
            text_parts << step[:textDelta]
            chunk = Message.new(
              content: step[:textDelta],
              role: :assistant,
              delta: true
            )
            block&.call(chunk)
          end

          # Thinking delta
          if step[:thinkingDelta] && !step[:thinkingDelta].empty?
            thinking_parts << step[:thinkingDelta]
          end

          # Custom tool action
          if step[:customTool]
            tool_calls_count += 1
            handle_custom_tool(step)
          end

          # Harness built-in tool actions count
          if step_record[:target] == :environment && step_record[:source] == :model
            tool_calls_count += 1 unless step[:customTool]
          end

          # Finished?
          if step[:state] && step[:state].to_s =~ /DONE|done|2/
            finished = true if step[:source].to_s =~ /MODEL|model|3/
          end
        end

        # Usage update
        if (usage = msg[:usageUpdate])
          update_usage(usage)
        end

        # Session end
        if msg.key?(:sessionEndResponse)
          :stop
        elsif finished
          # Small delay to catch trailing usage_update
          :stop
        end
      end

      # Build final message
      Message.new(
        content: text_parts.join,
        role: :assistant,
        thinking: thinking_parts.join,
        steps: steps,
        tool_calls_count: tool_calls_count,
        usage: @last_turn_usage.dup
      )
    end

    def handle_custom_tool(step)
      tool_data = step[:customTool]
      tool_name = tool_data[:name] || tool_data[:toolName]
      args = tool_data[:args] || tool_data[:arguments] || {}

      # Symbolize keys for Ruby kwargs
      kwargs = args.transform_keys(&:to_sym)

      begin
        result = @tool_runner.execute(tool_name, **kwargs)
      rescue ToolNotFoundError => e
        result = { error: e.message }
      end

      # Send tool response back
      tool_response = {
        toolResponse: {
          id: tool_data[:id],
          name: tool_name,
          result: result.is_a?(Hash) ? JSON.generate(result) : result.to_s
        },
        seqNum: next_seq
      }
      @ws.send_json(tool_response)
    end

    def parse_step(step)
      {
        step_index: step[:stepIndex],
        state: parse_state(step[:state]),
        source: parse_source(step[:source]),
        target: parse_target(step[:target]),
        text_delta: step[:textDelta],
        text: step[:text],
        thinking_delta: step[:thinkingDelta],
        error: step[:errorMessage],
        cascade_id: step[:cascadeId],
        trajectory_id: step[:trajectoryId]
      }
    end

    def parse_state(val)
      case val.to_s
      when /ACTIVE|1/ then :active
      when /DONE|2/   then :done
      when /WAITING|3/ then :waiting
      when /ERROR|4/  then :error
      else :unknown
      end
    end

    def parse_source(val)
      case val.to_s
      when /SYSTEM|1/ then :system
      when /USER|2/   then :user
      when /MODEL|3/  then :model
      else :unknown
      end
    end

    def parse_target(val)
      case val.to_s
      when /USER|1/        then :user
      when /MODEL|2/       then :model
      when /ENVIRONMENT|3/ then :environment
      else :unknown
      end
    end

    def update_usage(usage)
      meta = usage[:cumulativeUsage] || usage
      @last_turn_usage = {
        prompt_token_count: meta[:promptTokenCount].to_i,
        candidates_token_count: meta[:candidatesTokenCount].to_i,
        thoughts_token_count: meta[:thoughtsTokenCount].to_i,
        total_token_count: meta[:totalTokenCount].to_i,
        cached_content_token_count: meta[:cachedContentTokenCount].to_i
      }
      # Accumulate into total
      @last_turn_usage.each { |k, v| @total_usage[k] += v }
    end

    def empty_usage
      {
        prompt_token_count: 0,
        candidates_token_count: 0,
        thoughts_token_count: 0,
        total_token_count: 0,
        cached_content_token_count: 0
      }
    end

    def next_seq
      @seq_counter ||= 0
      @seq_counter += 1
    end
  end
end
