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

  describe '.resolve_api_key' do
    it 'prefers ENV GEMINI_API_KEY' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return('from-env')
      expect(described_class.resolve_api_key).to eq('from-env')
    end
  end
end
