# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'

RSpec.describe Antigravity::Jev::SseParser do
  let(:events) { [] }
  let(:parser) { described_class.new { |event| events << event } }

  it 'parses complete `data:` lines into JSON events' do
    parser.feed("data: {\"a\":1}\r\n\r\ndata: {\"a\":2}\r\n\r\n")
    expect(events).to eq([{ 'a' => 1 }, { 'a' => 2 }])
  end

  it 'buffers events split across chunks' do
    parser.feed('data: {"te')
    expect(events).to be_empty
    parser.feed("xt\":\"ciao\"}\n\n")
    expect(events).to eq([{ 'text' => 'ciao' }])
  end

  it 'handles multi-byte UTF-8 characters split across binary chunks' do
    bytes = "data: {\"t\":\"è\"}\n".b
    parser.feed(bytes[0, 13])
    parser.feed(bytes[13..])
    expect(events).to eq([{ 't' => 'è' }])
  end

  it 'ignores comments, blank lines and malformed JSON' do
    parser.feed(": keepalive\n\ndata: not-json\n\ndata: {\"ok\":true}\n")
    expect(events).to eq([{ 'ok' => true }])
  end
end
