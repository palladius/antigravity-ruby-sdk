# frozen_string_literal: true

# Integration tests for connection handshake and WebSocket session.
# Tagged :integration — requires localharness + GEMINI_API_KEY.

RSpec.describe Antigravity::Connection::LocalConnection, :integration do
  before(:all) do
    skip 'GEMINI_API_KEY not set' unless ENV['GEMINI_API_KEY']
    begin
      Antigravity::Connection::LocalConnection.find_binary!
    rescue Antigravity::HarnessNotFoundError
      skip 'localharness binary not found'
    end
  end

  after(:each) do
    @conn&.disconnect! rescue nil
  end

  it 'P0.2a: spawns localharness and completes stdio handshake + WebSocket' do
    @conn = described_class.new
    @conn.connect!

    expect(@conn).to be_connected
    expect(@conn.port).to be_a(Integer)
    expect(@conn.port).to be > 0
    expect(@conn.api_key).to be_a(String)
    expect(@conn.api_key).not_to be_empty
    expect(@conn.ws_client).to be_connected
  end

  it 'P0.2b: raises HarnessHandshakeError on corrupt binary' do
    conn = described_class.new(binary_path: '/usr/bin/false')
    expect {
      conn.connect!
    }.to raise_error(Antigravity::HarnessHandshakeError)
  end

  it 'P0.3a: initializes conversation session via WebSocket' do
    @conn = described_class.new
    @conn.connect!

    conversation = Antigravity::Conversation.new(ws_client: @conn.ws_client)
    harness_config = {
      initializeConversation: {
        harnessConfig: {
          model: 'gemini-2.5-flash',
          workspaceDir: Dir.pwd
        }
      }
    }
    conversation.initialize_session!(harness_config: harness_config)

    expect(conversation).to be_initialized
    expect(conversation.conversation_id).to be_a(String)
    expect(conversation.conversation_id).not_to be_empty
  end
end
