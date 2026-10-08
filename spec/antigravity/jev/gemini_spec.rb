# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'

RSpec.describe Antigravity::Jev::Gemini do
  let(:gemini) { described_class.new(api_key: 'test-key', fallback_model: 'gemini-3.7-flash') }

  def ok_body(parts)
    JSON.generate({ candidates: [{ content: { role: 'model', parts: parts } }] })
  end

  describe '.parse_model' do
    it 'splits a -low / -high suffix into model + thinkingLevel' do
      expect(described_class.parse_model('gemini-3.8-flash-low')).to eq(['gemini-3.8-flash', 'low'])
      expect(described_class.parse_model('gemini-3.8-flash-high')).to eq(['gemini-3.8-flash', 'high'])
    end

    it 'leaves plain model names untouched' do
      expect(described_class.parse_model('gemini-3.7-flash')).to eq(['gemini-3.7-flash', nil])
    end
  end

  describe '.parse_response' do
    it 'separates native thought parts from the answer and extracts the bash command' do
      body = JSON.parse(ok_body([
        { text: 'I should list files', thought: true },
        { text: "Ecco:\n```bash\nls -la\n```" }
      ]))
      reply = described_class.parse_response(body)

      expect(reply.thinking).to eq('I should list files')
      expect(reply.answer).to eq("Ecco:\n```bash\nls -la\n```")
      expect(reply.command).to eq('ls -la')
    end

    it 'still understands legacy <thought> tags' do
      body = JSON.parse(ok_body([{ text: "<thought>legacy plan</thought>\nRisposta" }]))
      reply = described_class.parse_response(body)

      expect(reply.thinking).to eq('legacy plan')
      expect(reply.answer).to eq('Risposta')
      expect(reply.command).to be_nil
    end
  end

  describe '#ask' do
    it 'sends the key as x-goog-api-key header (never in the URL) and the thinking level' do
      captured = nil
      allow(gemini).to receive(:post) do |model, payload|
        captured = [model, payload]
        [200, ok_body([{ text: 'ciao' }])]
      end

      gemini.ask('hello', model: 'gemini-3.8-flash-low')

      expect(captured[0]).to eq('gemini-3.8-flash')
      expect(captured[1].dig(:generationConfig, :thinkingConfig)).to eq(includeThoughts: true, thinkingLevel: 'low')
    end

    it 'keeps multi-turn history across calls' do
      allow(gemini).to receive(:post).and_return([200, ok_body([{ text: 'primo' }])])
      gemini.ask('domanda 1', model: 'gemini-3.7-flash')
      gemini.ask('domanda 2', model: 'gemini-3.7-flash')

      roles = gemini.history.map { |h| h[:role] }
      expect(roles).to eq(%w[user model user model])
      expect(gemini.history[2][:parts].first[:text]).to eq('domanda 2')
    end

    it 'falls back to fallback_model on 503 and reports the reason' do
      calls = []
      allow(gemini).to receive(:post) do |model, _payload|
        calls << model
        model == 'gemini-3.8-flash' ? [503, '{"error":{"message":"high demand"}}'] : [200, ok_body([{ text: 'ok' }])]
      end

      reply = gemini.ask('x', model: 'gemini-3.8-flash-high')

      expect(calls).to eq(%w[gemini-3.8-flash gemini-3.7-flash])
      expect(reply.answer).to eq('ok')
      expect(reply.model).to eq('gemini-3.7-flash')
      expect(reply.warnings.first).to include('503')
    end

    it 'raises a descriptive ApiError when every model fails (no silent fallback)' do
      allow(gemini).to receive(:post).and_return([404, '{"error":{"message":"not found"}}'])
      expect { gemini.ask('x', model: 'gemini-3.8-flash') }
        .to raise_error(Antigravity::Jev::ApiError, /404/)
    end
  end

  describe 'speed ⚡' do
    it 'uses a short configurable timeout (JEV_GEMINI_TIMEOUT, default 10s)' do
      expect(Antigravity::Jev.gemini_timeout).to eq(10)
      expect(gemini.timeout).to eq(10)

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('JEV_GEMINI_TIMEOUT').and_return('4')
      expect(Antigravity::Jev.gemini_timeout).to eq(4)
    end

    it 'is sticky: once a model failed, later calls skip it and go straight to the fallback' do
      calls = []
      allow(gemini).to receive(:post) do |model, _payload|
        calls << model
        model == 'gemini-3.8-flash' ? [0, 'Net::ReadTimeout'] : [200, ok_body([{ text: 'ok' }])]
      end

      gemini.ask('uno', model: 'gemini-3.8-flash-low')
      second = gemini.ask('due', model: 'gemini-3.8-flash-low')

      expect(calls).to eq(%w[gemini-3.8-flash gemini-3.7-flash gemini-3.7-flash])
      expect(second.warnings).to be_empty
      expect(gemini.degraded).to include('gemini-3.8-flash')
    end

    it 'supports a comma-separated fallback chain' do
      chain = described_class.new(api_key: 'k', fallback_model: 'gemini-3.7-flash, gemini-3.5-flash')
      calls = []
      allow(chain).to receive(:post) do |model, _payload|
        calls << model
        model == 'gemini-3.5-flash' ? [200, ok_body([{ text: 'ok' }])] : [503, '{"error":{"message":"busy"}}']
      end

      reply = chain.ask('x', model: 'gemini-3.8-flash-low')

      expect(calls).to eq(%w[gemini-3.8-flash gemini-3.7-flash gemini-3.5-flash])
      expect(reply.model).to eq('gemini-3.5-flash')
      expect(chain.fallback_model).to eq('gemini-3.7-flash')
    end

    it 'retries previously degraded models as a last resort instead of giving up' do
      calls = []
      allow(gemini).to receive(:post) do |model, _payload|
        calls << model
        case calls.size
        when 1, 3 then [503, '{}'] # 3.8 busy on call 1, 3.7 busy on call 2
        else [200, ok_body([{ text: 'ok' }])]
        end
      end
      gemini.ask('uno', model: 'gemini-3.8-flash') # 3.8 fails -> degraded, 3.7 ok
      reply = gemini.ask('due', model: 'gemini-3.8-flash') # 3.7 fails -> last resort 3.8

      expect(calls).to eq(%w[gemini-3.8-flash gemini-3.7-flash gemini-3.7-flash gemini-3.8-flash])
      expect(reply.model).to eq('gemini-3.8-flash')
    end

    it 'reset! clears the degraded list too' do
      allow(gemini).to receive(:post) do |model, _payload|
        model == 'gemini-3.8-flash' ? [503, '{}'] : [200, ok_body([{ text: 'ok' }])]
      end
      gemini.ask('uno', model: 'gemini-3.8-flash')
      gemini.reset!
      expect(gemini.degraded).to be_empty
    end
  end

  describe 'streaming 🌊 (SSE, fast first)' do
    it 'uses the stream seam when a block is given and yields thought/text parts live' do
      allow(gemini).to receive(:stream) do |model, _payload, &blk|
        expect(model).to eq('gemini-3.7-flash')
        blk.call(:thought, "Penso...\n")
        blk.call(:text, "Ecco:\n```bash\nls\n```")
        [200, [{ 'thought' => true, 'text' => "Penso...\n" }, { 'text' => "Ecco:\n```bash\nls\n```" }]]
      end
      seen = []

      reply = gemini.ask('x', model: 'gemini-3.7-flash') { |kind, text| seen << [kind, text] }

      expect(seen.map(&:first)).to eq(%i[thought text])
      expect(reply.thinking).to eq('Penso...')
      expect(reply.command).to eq('ls')
      expect(gemini.history.last[:parts].first[:text]).to include('Ecco')
    end

    it 'yields failover warnings live (so they print before the fallback output)' do
      allow(gemini).to receive(:stream) do |model, _payload, &blk|
        next [0, 'Net::ReadTimeout'] if model == 'gemini-3.8-flash'

        blk.call(:text, 'ok')
        [200, [{ 'text' => 'ok' }]]
      end
      seen = []

      gemini.ask('x', model: 'gemini-3.8-flash-low') { |kind, text| seen << [kind, text] }

      expect(seen.first[0]).to eq(:warning)
      expect(seen.first[1]).to include('gemini-3.8-flash')
      expect(seen.last).to eq([:text, 'ok'])
    end

    it 'catches Net::ReadTimeout explicitly with a readable connectivity message' do
      allow(gemini).to receive(:stream) do |model, _payload, &blk|
        raise Net::ReadTimeout if model == 'gemini-3.8-flash'

        blk.call(:text, 'ok')
        [200, [{ 'text' => 'ok' }]]
      end
      seen = []

      reply = gemini.ask('x', model: 'gemini-3.8-flash-low') { |kind, text| seen << [kind, text] }

      expect(seen.first[1]).to match(/gemini-3.8-flash: no answer within \d+s \(Net::ReadTimeout\)/)
      expect(reply.model).to eq('gemini-3.7-flash')
    end

    it 'has a short first-byte timeout (JEV_FIRST_BYTE_TIMEOUT)' do
      expect(gemini.first_byte_timeout).to eq(Antigravity::Jev.first_byte_timeout)
      expect(Antigravity::Jev.first_byte_timeout).to be < Antigravity::Jev.gemini_timeout
    end
  end

  describe 'HIGH thinking for complex prompts 🧠' do
    it 'defaults the smart (complex) model to a -high thinking tier' do
      allow(ENV).to receive(:[]).and_call_original
      %w[JEV_SMART_MODEL GEMINI_SMART_MODEL].each { |k| allow(ENV).to receive(:[]).with(k).and_return(nil) }
      expect(Antigravity::Jev.smart_model).to end_with('-high')
    end

    it 'gives medium/high thinking a longer budget (JEV_THINKING_TIMEOUT) for first byte and between chunks' do
      expect(Antigravity::Jev.thinking_timeout).to eq(30)
      expect(gemini.timeouts_for('high')).to eq([30, 30])
      expect(gemini.timeouts_for('medium')).to eq([30, 30])
      expect(gemini.timeouts_for('low')).to eq([gemini.first_byte_timeout, gemini.timeout])
      expect(gemini.timeouts_for(nil)).to eq([gemini.first_byte_timeout, gemini.timeout])
    end
  end

  describe '```bash final marker' do
    it 'flags commands whose output alone answers the request' do
      body = JSON.parse(ok_body([{ text: "Ecco:\n```bash final\nls -la\n```" }]))
      reply = described_class.parse_response(body)

      expect(reply.command).to eq('ls -la')
      expect(reply.final).to be true
    end

    it 'is not final by default' do
      reply = described_class.parse_response(JSON.parse(ok_body([{ text: "```bash\nls\n```" }])))
      expect(reply.final).to be_falsey
    end
  end

  describe '.resolve_api_key' do
    it 'prefers ENV GEMINI_API_KEY' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return('from-env')
      expect(described_class.resolve_api_key).to eq('from-env')
    end
  end
end
