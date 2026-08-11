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

  # Helper: create and connect an agent
  def create_agent(**kwargs)
    agent = Antigravity::Agent.new(**kwargs)
    agent.connect!
    agent
  end

  # ---------------------------------------------------------------------------
  # UAT-1: Codebase analysis ("What is this codebase doing?")
  # Mirror of Python: response = await agent.chat("What is this codebase?")
  # ---------------------------------------------------------------------------
  describe 'UAT-1: Codebase analysis' do
    it 'asks the agent to describe a directory and gets a substantive response' do
      @agent = create_agent(workspace: File.expand_path('~/git/antigravity-ruby-sdk'))
      response = @agent.ask('Based on the directory name and common Ruby conventions, what does this codebase likely do? Be brief, 2-3 sentences max. Do NOT use any tools, just answer directly.')

      expect(response).to be_a(Antigravity::Message)
      expect(response.content).to be_a(String)
      expect(response.content.length).to be > 50  # not empty/trivial
      expect(response.content).to match(/ruby|sdk|antigravity|agent|gem/i)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-2: Response metadata (like Python's ChatResponse)
  # ---------------------------------------------------------------------------
  describe 'UAT-2: Response metadata' do
    it 'returns usage metadata with token counts' do
      @agent = create_agent
      response = @agent.ask('Say exactly: OK')

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
      @agent = create_agent(system_instruction: 'You are a calculator. Answer math questions with just the number. Do NOT use any tools.')
      @agent.ask('What is 1 + 1? Just the number.')

      expect(@agent.conversation_id).to be_a(String)
      expect(@agent.conversation_id).not_to be_empty
    end

    it 'counts turns across multiple exchanges' do
      @agent = create_agent(system_instruction: 'You are a simple echo bot. Reply with just the letter requested. Do NOT use any tools.')
      @agent.ask('Say A. Reply with just: A')
      @agent.ask('Say B. Reply with just: B')
      @agent.ask('Say C. Reply with just: C')

      expect(@agent.turn_count).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-3: Tool calls with metadata
  # ---------------------------------------------------------------------------
  describe 'UAT-3: Tool usage tracking' do
    it 'counts tool calls in the response' do
      tool = Antigravity::Tool.define(:get_weather,
        desc: 'Gets current weather for a city',
        params: { city: { type: :string, description: 'City name' } }
      ) { |city:| "Sunny, 28C in #{city}" }

      @agent = create_agent(
        system_instruction: 'Always use get_weather for weather questions. Report the exact tool result.',
        tools: [tool]
      )
      response = @agent.ask('What is the weather in Milan?')

      expect(response.tool_calls_count).to be >= 1
      expect(response.content).to include('28')
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-4: Streaming with chunk accumulation
  # ---------------------------------------------------------------------------
  describe 'UAT-4: Streaming' do
    it 'streams real LLM tokens via block (not instant mock)' do
      chunks = []
      timings = []
      @agent = create_agent

      response = @agent.ask('Write a 4-line poem about Ruby programming') do |chunk|
        if chunk.content && !chunk.content.empty?
          chunks << chunk.content
          timings << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      expect(chunks.length).to be > 1
      expect(chunks.join.length).to be > 30
      expect(timings.last - timings.first).to be > 0.1 if timings.length > 1
      expect(response.content).to eq(chunks.join)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-5: System instructions shape behavior
  # ---------------------------------------------------------------------------
  describe 'UAT-5: System instructions' do
    it 'shapes the model response according to instructions' do
      @agent = create_agent(
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
      Antigravity::Agent.open(system_instruction: 'Reply with just OK when asked. Do NOT use any tools.') do |agent|
        response = agent.ask('Say OK. Reply with just: OK')
        expect(agent).to be_connected
      end
      expect(response.content).to match(/OK/i)
    end

    it 'close! is idempotent and cleans up' do
      @agent = create_agent
      @agent.ask('Hello')
      expect { @agent.close! }.not_to raise_error
      expect(@agent).not_to be_connected
      expect { @agent.close! }.not_to raise_error  # idempotent
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-7: Rich response introspection (harness-side tool actions)
  # ---------------------------------------------------------------------------
  describe 'UAT-7: Custom tool call tracking in steps' do
    it 'records tool calls in the response metadata' do
      tool = Antigravity::Tool.define(:reverse_text,
        desc: 'Reverses a string',
        params: { text: { type: :string, description: 'Text to reverse' } }
      ) { |text:| text.reverse }

      @agent = create_agent(
        system_instruction: 'Always use reverse_text for any text reversal request.',
        tools: [tool]
      )
      response = @agent.ask('Reverse the word: hello')

      expect(response.tool_calls_count).to be >= 1
      expect(response.content).to match(/olleh/i)
    end
  end

  # ---------------------------------------------------------------------------
  # UAT-8: Session summary / reflection
  # ---------------------------------------------------------------------------
  describe 'UAT-8: Session summary' do
    it 'produces a human-readable session summary' do
      @agent = create_agent
      @agent.ask('What is 2 + 2? Answer with just the number.')

      summary = @agent.session_summary
      expect(summary).to be_a(Hash)
      expect(summary[:conversation_id]).to be_a(String)
      expect(summary[:turn_count]).to eq(1)
      expect(summary[:total_tokens]).to be_a(Integer)
      expect(summary[:total_tokens]).to be > 0
      expect(summary[:model]).to be_a(String)

      puts "\n--- Session Summary ---"
      summary.each { |k, v| puts "  #{k}: #{v}" }
      puts "----------------------"
    end
  end
end
