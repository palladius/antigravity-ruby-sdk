# frozen_string_literal: true

# Acceptance tests mirroring the Python SDK's ChatResponse API.
# These are the "real deal" — spawn harness, talk to Gemini, verify metadata.
#
# Run with: just integration
# Requires: localharness binary + GEMINI_API_KEY

RSpec.describe 'Acceptance Tests', :integration do
  before(:all) do
    skip 'GEMINI_API_KEY not set' unless ENV['GEMINI_API_KEY']
    begin
      Antigravity::Connection::LocalConnection.find_binary!
    rescue Antigravity::HarnessNotFoundError
      skip 'localharness binary not found'
    end
  end

  after(:each) { @agent&.close! rescue nil }

  # ---------------------------------------------------------------------------
  # UAT-1: Codebase analysis ("What is this codebase doing?")
  # Mirror of Python: response = await agent.chat("What is this codebase?")
  # ---------------------------------------------------------------------------
  describe 'UAT-1: Codebase analysis' do
    it 'asks the agent to describe a directory and gets a substantive response' do
      @agent = Antigravity::Agent.new(
        workspace: File.expand_path('~/git/antigravity-ruby-sdk')
      )
      response = @agent.ask('What is this codebase doing? Be brief, 2-3 sentences max.')

      expect(response).to be_a(Antigravity::Message)
      expect(response.content).to be_a(String)
      expect(response.content.length).to be > 50  # not empty/trivial
      expect(response.content).to match(/ruby|sdk|antigravity|agent|gem/i)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-2: Response metadata (like Python's ChatResponse)
  #   response.usage_metadata => UsageMetadata
  #   response.tool_calls_count
  #   response.turn_count
  #   response.conversation_id / cascade_id
  # ---------------------------------------------------------------------------
  describe 'UAT-2: Response metadata' do
    it 'returns usage metadata with token counts' do
      @agent = Antigravity::Agent.new
      response = @agent.ask('Say exactly: OK')

      # Token usage (mirrors Python's response.usage_metadata)
      usage = response.usage
      expect(usage).to be_a(Hash)
      expect(usage[:prompt_token_count]).to be_a(Integer)
      expect(usage[:prompt_token_count]).to be > 0
      expect(usage[:candidates_token_count]).to be_a(Integer)
      expect(usage[:candidates_token_count]).to be > 0
      expect(usage[:total_token_count]).to be_a(Integer)
      expect(usage[:total_token_count]).to be >= usage[:prompt_token_count] + usage[:candidates_token_count]
    end

    it 'tracks conversation_id / cascade_id' do
      @agent = Antigravity::Agent.new
      @agent.ask('Hello')

      # Mirrors Python's agent.conversation_id
      expect(@agent.conversation_id).to be_a(String)
      expect(@agent.conversation_id).not_to be_empty
    end

    it 'counts turns across multiple exchanges' do
      @agent = Antigravity::Agent.new
      @agent.ask('Say A')
      @agent.ask('Say B')
      @agent.ask('Say C')

      # Mirrors Python's agent.conversation.turn_count
      expect(@agent.turn_count).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-3: Tool calls with metadata
  #   - agent uses a tool
  #   - response reports tool_calls_count > 0
  #   - tool result is reflected in the response
  # ---------------------------------------------------------------------------
  describe 'UAT-3: Tool usage tracking' do
    it 'counts tool calls in the response' do
      tool = Antigravity::Tool.define(:get_weather,
        desc: 'Gets current weather for a city',
        params: { city: { type: :string, description: 'City name' } }
      ) { |city:| "Sunny, 28C in #{city}" }

      @agent = Antigravity::Agent.new(
        system_instruction: 'Always use get_weather for weather questions. Report the exact tool result.',
        tools: [tool]
      )
      response = @agent.ask('What is the weather in Milan?')

      # Mirrors counting tool_calls from Python's response.chunks
      expect(response.tool_calls_count).to be >= 1
      expect(response.content).to include('28')
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-4: Streaming with chunk accumulation
  #   - text arrives in multiple chunks over time
  #   - block receives chunk objects with .content
  # ---------------------------------------------------------------------------
  describe 'UAT-4: Streaming' do
    it 'streams real LLM tokens via block (not instant mock)' do
      chunks = []
      timings = []
      @agent = Antigravity::Agent.new

      response = @agent.ask('Write a 4-line poem about Ruby programming') do |chunk|
        if chunk.content
          chunks << chunk.content
          timings << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      # Multiple chunks
      expect(chunks.length).to be > 1
      # Content is non-trivial
      expect(chunks.join.length).to be > 30
      # Streaming took real time (not instant)
      expect(timings.last - timings.first).to be > 0.1
      # Final response also has the full text
      expect(response.content).to eq(chunks.join)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-5: System instructions shape behavior
  # ---------------------------------------------------------------------------
  describe 'UAT-5: System instructions' do
    it 'shapes the model response according to instructions' do
      @agent = Antigravity::Agent.new(
        system_instruction: 'You are a pirate. Every response must include "ARRR" and "matey".'
      )
      response = @agent.ask('Hello, who are you?')

      expect(response.content).to match(/arrr/i)
      expect(response.content).to match(/matey/i)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-6: Agent lifecycle (open/close, block form)
  # ---------------------------------------------------------------------------
  describe 'UAT-6: Lifecycle' do
    it 'Agent.open auto-closes and returns the response' do
      response = nil
      Antigravity::Agent.open do |agent|
        response = agent.ask('Say OK')
        expect(agent).to be_connected
      end
      expect(response.content).to include('OK')
    end

    it 'close! is idempotent and cleans up' do
      @agent = Antigravity::Agent.new
      @agent.ask('Hello')
      expect { @agent.close! }.not_to raise_error
      expect(@agent).not_to be_connected
      expect { @agent.close! }.not_to raise_error  # idempotent
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-7: Rich response introspection (harness-side tool actions)
  #   When the agent uses built-in tools (list_dir, view_file, etc.)
  #   the response should report them in steps
  # ---------------------------------------------------------------------------
  describe 'UAT-7: Harness tool introspection' do
    it 'reports harness-side tool calls (list_dir, view_file, etc.) in steps' do
      @agent = Antigravity::Agent.new(
        workspace: File.expand_path('~/git/antigravity-ruby-sdk')
      )
      response = @agent.ask('List the files in the lib/ directory. Just list them.')

      # The agent should have used list_dir or similar
      expect(response.steps).to be_an(Array)
      expect(response.steps.length).to be > 0

      # At least one step should be a tool action
      tool_steps = response.steps.select { |s| s[:source] == :model && s[:target] == :environment }
      expect(tool_steps).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-8: Session summary / reflection
  #   Print a human-readable summary of what happened
  # ---------------------------------------------------------------------------
  describe 'UAT-8: Session summary' do
    it 'produces a human-readable session summary' do
      @agent = Antigravity::Agent.new
      response = @agent.ask('What is 2 + 2? Answer with just the number.')

      summary = @agent.session_summary
      expect(summary).to be_a(Hash)
      expect(summary[:conversation_id]).to be_a(String)
      expect(summary[:turn_count]).to eq(1)
      expect(summary[:total_tokens]).to be_a(Integer)
      expect(summary[:total_tokens]).to be > 0
      expect(summary[:model]).to be_a(String)

      # Print it for human review in test output
      puts "\n--- Session Summary ---"
      summary.each { |k, v| puts "  #{k}: #{v}" }
      puts "----------------------"
    end
  end
end
