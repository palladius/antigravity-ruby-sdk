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

    def initialize(ws_client:, tool_runner: nil, hooks: nil)
      @ws = ws_client
      @tool_runner = tool_runner || ToolRunner.new
      @hooks = hooks
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
    def chat(prompt, timeout: Antigravity.config.timeout_llm, &block)
      raise ProtocolError, 'Session not initialized' unless @initialized

      @turn_count += 1
      @last_turn_usage = empty_usage

      # GHI #18: Drain any stale messages from the WebSocket buffer before sending
      # a new prompt. This prevents leftover FULLY_IDLE from previous turns or init
      # from being consumed by collect_response.
      drain_stale_messages

      # Send user input (protobuf InputEvent with user_input string field)
      input_event = {
        userInput: prompt
      }
      @ws.send_json(input_event)

      # Collect response
      collect_response(timeout: timeout, &block)
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

    # GHI #18: Non-blocking drain of stale WebSocket messages (FULLY_IDLE leftovers).
    # During gaps between turns (e.g. voice transcription taking 5-10s), the harness
    # may send trajectory updates that would confuse the next collect_response call.
    def drain_stale_messages
      drained = 0
      loop do
        msg = @ws.receive_json(timeout: 0.05, idle_timeout: 0.05) rescue nil
        break unless msg
        drained += 1
        @hooks&.emit(:ws_message, { _debug: 'drained_stale_message', message_keys: msg.keys, drained_count: drained })
      end
      @hooks&.emit(:ws_message, { _debug: 'drain_complete', count: drained }) if drained > 0
    end

    def collect_response(timeout: Antigravity.config.timeout_llm, &block)
      text_parts = []
      thinking_parts = []
      steps = []
      tool_calls_count = 0
      finished = false
      finished_at = nil
      seen_any_step = false          # GHI #18: track if we've seen real work from this turn
      turn_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @ws.each_message(timeout: timeout) do |msg|
        @hooks&.emit(:ws_message, msg)

        if (step = msg[:stepUpdate])
          seen_any_step = true
          step_record = parse_step(step)
          steps << step_record

          # Text delta — stream it (only from model aimed at user, not tool descriptions or error steps)
          is_model_step = step[:source].to_s =~ /MODEL|model|3/
          is_target_user = step[:target].to_s =~ /USER|user|1/
          is_error_step = step[:state].to_s =~ /ERROR|error|4/ || step[:errorMessage]

          if step[:textDelta] && !step[:textDelta].empty? && is_model_step && is_target_user && !is_error_step
            text_parts << step[:textDelta]
            chunk = Chunk.new(
              content: step[:textDelta],
              role: :assistant
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

          # Finished? Model response to user with DONE state AND text collected.
          # NOTE: DONE can arrive before text deltas, so we require text here.
          # For tool-only turns (no text), FULLY_IDLE below is the authoritative stop.
          if is_model_step && is_target_user && !is_error_step && step[:state] && step[:state].to_s =~ /DONE|done|2/ && !text_parts.empty?
            finished = true
          end
        end

        # Top-level tool call (custom tools are sent as separate messages, not in stepUpdate)
        if (tool_call = msg[:toolCall])
          tool_calls_count += 1
          seen_any_step = true
          handle_tool_call(tool_call)
        end

        # Usage update — do NOT set seen_any_step here!
        # usageUpdate can leak from the previous turn and trick the GHI #18
        # stale-FULLY_IDLE guard into accepting a stale FULLY_IDLE as real.
        if (usage = msg[:usageUpdate])
          update_usage(usage)
        end

        # Trajectory state: STATE_FULLY_IDLE / STATE_CANCELLED = turn complete (authoritative signal from harness)
        # GHI #18 + #24 FIX: Only honor FULLY_IDLE if we've seen at least one stepUpdate or toolCall
        # (NOT usageUpdate — it leaks across turns) from this turn, OR if enough time has elapsed
        # (2s) that this can't be a stale leftover. A stale FULLY_IDLE from a previous turn sitting
        # in the WebSocket buffer was causing collect_response to return immediately with 0B text.
        if (traj = msg[:trajectoryStateUpdate])
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - turn_started_at
          if traj[:state].to_s =~ /FULLY_IDLE|CANCELLED/
            if seen_any_step || elapsed > 2.0
              finished = true
              finished_at = Time.now
            else
              # Stale FULLY_IDLE — skip it (likely leftover from previous turn or init)
              @hooks&.emit(:ws_message, { _debug: 'skipped_stale_fully_idle', elapsed: elapsed.round(3), seen_any_step: seen_any_step })
            end
          end
        end

        # Stop conditions (in priority order):
        # 1. Session end — always hard-stop immediately
        # 2. Model DONE + text collected — drain briefly for trailing usage/metadata
        # 3. Trajectory FULLY_IDLE/CANCELLED — drain briefly for trailing text/usage (GHI #24 fix)
        #    Without this drain, fast turns can lose text deltas that arrive after FULLY_IDLE.
        if msg.key?(:sessionEndResponse)
          :stop
        elsif finished
          [:idle_timeout, 0.5]
        elsif !text_parts.empty?
          # If assistant has sent text but no DONE/FULLY_IDLE yet, allow 3s idle timeout
          [:idle_timeout, 3.0]
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
      tool_call = tool_data[:toolCall] || tool_data
      handle_tool_call(tool_call)
    end

    # Handle a top-level toolCall message from the harness
    # Format: {id: "...", name: "tool_name", argumentsJson: "{...}"}
    def handle_tool_call(tool_call)
      tool_id = tool_call[:id]
      tool_name = tool_call[:name]

      # Parse arguments from JSON string
      args_json = tool_call[:argumentsJson] || tool_call[:arguments_json]
      args = if args_json.is_a?(String) && !args_json.empty?
               JSON.parse(args_json, symbolize_names: true)
             elsif tool_call[:arguments].is_a?(Hash)
               tool_call[:arguments]
             else
               {}
             end

      # Symbolize keys for Ruby kwargs
      kwargs = args.transform_keys(&:to_sym)

      # Emit tool_call hook BEFORE execution
      @hooks&.emit(:tool_call, { tool_name: tool_name, params: args, tool_id: tool_id })

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      policy_check = @hooks ? @hooks.run_pre_tool(tool_name, args) : { allowed: true }

      if !policy_check[:allowed]
        reason = policy_check[:reason]
        # Same format as client.rb sidecar emission
        @hooks&.emit(:tool_blocked, { tool: tool_name, reason: reason })
        result = "❌ TOOL BLOCKED: #{reason}"
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        
        # We run the post_tool hook here as well to satisfy AgentLogger's pairing
        result = @hooks ? @hooks.run_post_tool(tool_name, args, result) : result
        @hooks&.emit(:tool_result, { tool_name: tool_name, result: result.to_s, duration: duration, tool_id: tool_id })
      else
        begin
          raw_result = @tool_runner.execute(tool_name, **kwargs)
          
          # Run post_tool filters/maskers
          result = @hooks ? @hooks.run_post_tool(tool_name, args, raw_result) : raw_result
          
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

          # Emit tool_result hook AFTER execution
          @hooks&.emit(:tool_result, { tool_name: tool_name, result: result.to_s, duration: duration, tool_id: tool_id })
        rescue ToolNotFoundError => e
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
          result = { error: e.message }

          # Emit tool_error hook on failure
          @hooks&.emit(:tool_error, { tool_name: tool_name, error: e.message, duration: duration, tool_id: tool_id })
        end
      end

      # Send tool response back (protobuf InputEvent.tool_response format)
      # The harness expects responseJson to be a JSON object (Python SDK wraps in {"result": ...})
      result_dict = result.is_a?(Hash) ? result : { result: result.to_s }
      tool_response = {
        toolResponse: {
          id: tool_id,
          responseJson: JSON.generate(result_dict)
        }
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
      # The harness sends: { total: { promptTokenCount: "3855", ... }, agents: [...] }
      # Fall back to cumulativeUsage (legacy) or flat usage hash
      meta = usage[:total] || usage[:cumulativeUsage] || usage
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
