# frozen_string_literal: true

# Integration tests for connection handshake and WebSocket session.
# Tagged :integration — requires localharness + GEMINI_API_KEY.

RSpec.describe Antigravity::Connection::LocalConnection, :integration do
  before(:all) do
    skip 'GEMINI_API_KEY not set' unless ENV['GEMINI_API_KEY']
    begin
      @binary = Antigravity::Connection::LocalConnection.find_binary!
    rescue Antigravity::HarnessNotFoundError
      skip 'localharness binary not found'
    end
  end

  after(:each) do
    @conn&.disconnect! rescue nil
  end

  it 'P0.2a: spawns localharness and completes stdio handshake' do
    @conn = described_class.new
    @conn.connect!

    expect(@conn).to be_connected
    expect(@conn.port).to be_a(Integer)
    expect(@conn.port).to be > 0
    expect(@conn.api_key).to be_a(String)
    expect(@conn.api_key).not_to be_empty
  end

  it 'P0.2b: raises HarnessHandshakeError on corrupt binary' do
    conn = described_class.new(binary_path: '/usr/bin/false')
    expect {
      conn.connect!
    }.to raise_error(Antigravity::HarnessHandshakeError)
  end

  it 'P0.3a: connects WebSocket and sends InitializeConversationEvent' do
    @conn = described_class.new
    @conn.connect!
    response = @conn.initialize_session!

    expect(response).to be_a(Hash)
    expect(response[:cascade_id]).to be_a(String)
  end
end
