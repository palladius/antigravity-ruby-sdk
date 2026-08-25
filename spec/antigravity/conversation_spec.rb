# frozen_string_literal: true

# Unit tests for the GHI #24 fix: FULLY_IDLE drain behavior in Conversation#collect_response.
#
# These tests mock the WebSocket client to simulate the exact message ordering
# that causes the race condition: FULLY_IDLE arriving before text deltas finish.

require 'spec_helper'

RSpec.describe Antigravity::Conversation do
  # A mock WebSocket client that replays a scripted sequence of messages.
  # drain_stale_messages calls receive_json with short timeouts — we return nil
  # for those (nothing stale), then replay messages for each_message.
  class MockWsClient
    attr_reader :sent_messages

    def initialize(messages)
      @messages = messages.dup
      @sent_messages = []
      @current_idle_timeout = nil
    end

    def send_json(msg)
      @sent_messages << msg
    end

    def receive_json(timeout: 30, idle_timeout: nil)
      # Short timeout = drain call → return nil (no stale messages)
      return nil if timeout <= 0.1

      return nil if @messages.empty?
      @messages.shift
    end

    def each_message(timeout: 30, &block)
      loop do
        msg = receive_json(timeout: timeout, idle_timeout: @current_idle_timeout)
        break unless msg

        result = block.call(msg)
        if result.is_a?(Array) && result.first == :idle_timeout
          @current_idle_timeout = result.last
        elsif result == :stop
          @current_idle_timeout = nil
          break
        end
      end
    ensure
      @current_idle_timeout = nil
    end
  end

  let(:tool_runner) { Antigravity::ToolRunner.new }
  let(:hooks) { Antigravity::Hooks.new }

  # Helper: build a stepUpdate message with text delta from model->user
  def step_text(text, state: 'ACTIVE')
    {
      stepUpdate: {
        stepIndex: 0,
        source: 'MODEL',
        target: 'USER',
        textDelta: text,
        state: state
      }
    }
  end

  # Helper: build a FULLY_IDLE trajectory state update
  def fully_idle
    {
      trajectoryStateUpdate: {
        state: 'STATE_FULLY_IDLE'
      }
    }
  end

  # Helper: build a usageUpdate message
  def usage_update(total: 100, prompt: 40, candidates: 60)
    {
      usageUpdate: {
        totalTokenCount: total,
        promptTokenCount: prompt,
        candidatesTokenCount: candidates
      }
    }
  end

  # Helper: build a session end response
  def session_end
    { sessionEndResponse: {} }
  end

  # Helper: create a conversation with a mock WS client
  def build_conversation(messages)
    ws = MockWsClient.new(messages)
    conv = Antigravity::Conversation.new(ws_client: ws, tool_runner: tool_runner, hooks: hooks)
    # Simulate initialized state
    conv.instance_variable_set(:@initialized, true)
    conv.instance_variable_set(:@conversation_id, 'test-conv')
    [conv, ws]
  end

  # ---------------------------------------------------------------------------
  # GHI #24: The core race condition fix
  # ---------------------------------------------------------------------------
  describe 'GHI #24: FULLY_IDLE drain behavior' do
    context 'when text arrives BEFORE FULLY_IDLE (normal case)' do
      it 'captures the text and returns a non-empty response' do
        messages = [
          step_text('Ruby is great!', state: 'DONE'),
          usage_update(total: 100),
          fully_idle
        ]
        conv, = build_conversation(messages)
        response = conv.chat('What makes Ruby great?')

        expect(response.content).to eq('Ruby is great!')
        expect(response.content.bytesize).to be > 0
      end
    end

    context 'when FULLY_IDLE arrives BEFORE text (the race condition)' do
      it 'drains after FULLY_IDLE and captures trailing text' do
        messages = [
          usage_update(total: 100),            # usage arrives first
          fully_idle,                           # FULLY_IDLE before text!
          step_text('Ruby is awesome!', state: 'DONE'),  # text arrives during drain
        ]
        conv, = build_conversation(messages)
        response = conv.chat('What makes Ruby awesome?')

        # The drain should have captured the trailing text
        expect(response.content).to eq('Ruby is awesome!')
        expect(response.content.bytesize).to be > 0
      end
    end

    context 'when FULLY_IDLE arrives with NO trailing text at all' do
      it 'returns empty content after drain timeout (no hang)' do
        messages = [
          usage_update(total: 50),
          fully_idle
          # nothing else follows - drain will time out cleanly
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Hello?')

        # No text was sent, so content is empty - but we did not hang
        expect(response.content).to eq('')
        expect(response).to be_a(Antigravity::Message)
      end
    end

    context 'when text arrives in multiple deltas then FULLY_IDLE' do
      it 'concatenates all text deltas correctly' do
        messages = [
          step_text('Ruby '),
          step_text('is '),
          step_text('beautiful!', state: 'DONE'),
          fully_idle,
          usage_update(total: 200)
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Tell me about Ruby')

        expect(response.content).to eq('Ruby is beautiful!')
      end
    end

    context 'when session end arrives (should hard-stop, not drain)' do
      it 'stops immediately without draining' do
        messages = [
          step_text('bye', state: 'DONE'),
          session_end
        ]
        conv, = build_conversation(messages)
        response = conv.chat('goodbye')

        expect(response.content).to eq('bye')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GHI #18: Stale FULLY_IDLE from previous turn
  # ---------------------------------------------------------------------------
  describe 'GHI #18: stale FULLY_IDLE rejection' do
    context 'when FULLY_IDLE arrives before any step/usage (stale leftover)' do
      it 'skips the stale FULLY_IDLE and waits for real data' do
        messages = [
          fully_idle,                              # stale from previous turn
          step_text('Hello!', state: 'DONE'),      # real response
          fully_idle                               # real FULLY_IDLE
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Hi')

        expect(response.content).to eq('Hello!')
        expect(response.content.bytesize).to be > 0
      end
    end

    context 'when usageUpdate + FULLY_IDLE leak from previous turn (the T3 bug)' do
      it 'does NOT let usageUpdate trick the stale guard' do
        # This is the exact sequence that caused 0B on T3:
        # A leaked usageUpdate from T2 set seen_any_step=true,
        # then a leaked FULLY_IDLE was accepted as real.
        messages = [
          usage_update(total: 7500),               # leaked from previous turn
          fully_idle,                               # also leaked from previous turn
          step_text('Ruby rocks!', state: 'DONE'),  # real response for THIS turn
          fully_idle                                # real FULLY_IDLE for THIS turn
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Tell me about Ruby')

        expect(response.content).to eq('Ruby rocks!')
        expect(response.content.bytesize).to be > 0
      end
    end

    context 'when only usageUpdate arrives before FULLY_IDLE (no stepUpdate)' do
      it 'treats FULLY_IDLE as stale since usageUpdate alone is not real work' do
        messages = [
          usage_update(total: 500),                # could be from prev turn
          fully_idle,                               # stale
          step_text('Real answer', state: 'DONE'), # actual response
          usage_update(total: 1000),               # real usage
          fully_idle                                # real completion
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Question')

        expect(response.content).to eq('Real answer')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Usage metadata
  # ---------------------------------------------------------------------------
  describe 'usage metadata capture' do
    it 'captures token counts from usageUpdate' do
      messages = [
        step_text('OK', state: 'DONE'),
        usage_update(total: 150, prompt: 50, candidates: 100),
        fully_idle
      ]
      conv, = build_conversation(messages)
      response = conv.chat('Say OK')

      expect(response.usage[:total_token_count]).to eq(150)
      expect(response.usage[:prompt_token_count]).to eq(50)
      expect(response.usage[:candidates_token_count]).to eq(100)
    end

    context 'when usageUpdate arrives AFTER FULLY_IDLE' do
      it 'captures usage during the drain window' do
        messages = [
          step_text('OK', state: 'DONE'),
          fully_idle,
          usage_update(total: 200, prompt: 80, candidates: 120)  # after FULLY_IDLE
        ]
        conv, = build_conversation(messages)
        response = conv.chat('Say OK')

        expect(response.usage[:total_token_count]).to eq(200)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tool calls count
  # ---------------------------------------------------------------------------
  describe 'tool calls tracking' do
    it 'counts top-level toolCall messages' do
      ping_tool = Antigravity::Tool::Dynamic.new('ping', description: 'ping') { 'pong' }
      tool_runner.register(ping_tool)

      messages = [
        { toolCall: { id: 'tc1', name: 'ping', argumentsJson: '{}' } },
        step_text('Done!', state: 'DONE'),
        fully_idle
      ]
      conv, = build_conversation(messages)
      response = conv.chat('ping me')

      expect(response.tool_calls_count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # Turn counter
  # ---------------------------------------------------------------------------
  describe 'turn_count' do
    it 'increments on each chat call' do
      messages = [
        step_text('one', state: 'DONE'), fully_idle,
        step_text('two', state: 'DONE'), fully_idle
      ]
      conv, = build_conversation(messages)

      conv.chat('first')
      expect(conv.turn_count).to eq(1)

      conv.chat('second')
      expect(conv.turn_count).to eq(2)
    end
  end

  describe '#parse_builtin_tool_text' do
    # parse_builtin_tool_text is private, so we test via send
    let(:conv) do
      ws = double('ws')
      allow(ws).to receive(:connected?).and_return(true)
      described_class.new(ws_client: ws, tool_runner: nil, hooks: nil)
    end

    it 'parses "Web search for prime counts" as WebSearch' do
      name, params = conv.send(:parse_builtin_tool_text, 'Web search for prime counts')
      expect(name).to eq('WebSearch')
      expect(params).to include('prime counts')
    end

    it 'parses "Read /etc/hosts" as Read' do
      name, params = conv.send(:parse_builtin_tool_text, 'Read /etc/hosts')
      expect(name).to eq('Read')
      expect(params).to include('/etc/hosts')
    end

    it 'parses "Running `ls -la`" as RunCommand' do
      name, params = conv.send(:parse_builtin_tool_text, 'Running `ls -la`')
      expect(name).to eq('RunCommand')
      expect(params).to include('ls -la')
    end

    it 'parses "Edit /path/to/file.rb" as Edit' do
      name, params = conv.send(:parse_builtin_tool_text, 'Edit /path/to/file.rb')
      expect(name).to eq('Edit')
      expect(params).to include('/path/to/file.rb')
    end

    it 'parses "Grep patterns in /src" as Search' do
      name, params = conv.send(:parse_builtin_tool_text, 'Grep patterns in /src')
      expect(name).to eq('Search')
      expect(params).to include('patterns')
    end

    it 'returns empty for nil/blank text' do
      name, params = conv.send(:parse_builtin_tool_text, '')
      expect(name).to eq('')
    end

    it 'handles generic text by capitalizing first word' do
      name, params = conv.send(:parse_builtin_tool_text, 'Analyzing code quality')
      expect(name).to eq('Analyzing')
      expect(params).to include('code quality')
    end
  end
end
