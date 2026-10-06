# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'

RSpec.describe Antigravity::Jev::Client do
  let(:dummy_api_key) { 'apikey_test1234567890abcdef' }

  describe 'initialization & API key resolution' do
    it 'accepts an explicit api_key' do
      client = described_class.new(api_key: dummy_api_key)
      expect(client.api_key).to eq(dummy_api_key)
    end

    it "resolves api_key from ENV['JEV_API_KEY_RUJEV']" do
      original_rujev = ENV['JEV_API_KEY_RUJEV']
      original_gic = ENV['GIC']
      begin
        ENV['JEV_API_KEY_RUJEV'] = 'apikey_from_rujev_env'
        ENV['GIC'] = nil
        client = described_class.new
        expect(client.api_key).to eq('apikey_from_rujev_env')
      ensure
        ENV['JEV_API_KEY_RUJEV'] = original_rujev
        ENV['GIC'] = original_gic
      end
    end

    it 'falls back to parsing JEV_API_KEY_RUJEV from $GIC/.env' do
      original_rujev = ENV['JEV_API_KEY_RUJEV']
      original_gic = ENV['GIC']
      begin
        ENV['JEV_API_KEY_RUJEV'] = nil
        Dir.mktmpdir do |dir|
          ENV['GIC'] = dir
          File.write(File.join(dir, '.env'), "JEV_API_KEY_RUJEV='apikey_from_gic_rujev_env'\n")
          client = described_class.new
          expect(client.api_key).to eq('apikey_from_gic_rujev_env')
        end
      ensure
        ENV['JEV_API_KEY_RUJEV'] = original_rujev
        ENV['GIC'] = original_gic
      end
    end

    it 'raises AuthenticationError when JEV_API_KEY_RUJEV is not found and not in mock mode' do
      original_rujev = ENV['JEV_API_KEY_RUJEV']
      original_gic = ENV['GIC']
      begin
        ENV['JEV_API_KEY_RUJEV'] = nil
        ENV['GIC'] = '/nonexistent/path/gic'
        expect do
          described_class.new
        end.to raise_error(Antigravity::Jev::AuthenticationError, /JEV_API_KEY_RUJEV/)
      ensure
        ENV['JEV_API_KEY_RUJEV'] = original_rujev
        ENV['GIC'] = original_gic
      end
    end

    it 'allows initialization without key when mock: true' do
      original_jev = ENV['JEV_API_KEY']
      original_ts = ENV['TYPESAFE_API_KEY']
      begin
        ENV['JEV_API_KEY'] = nil
        ENV['TYPESAFE_API_KEY'] = nil
        client = described_class.new(mock: true)
        expect(client.mock?).to be true
      ensure
        ENV['JEV_API_KEY'] = original_jev
        ENV['TYPESAFE_API_KEY'] = original_ts
      end
    end
  end

  describe '#systemone' do
    let(:client) { described_class.new(api_key: dummy_api_key) }

    it 'sends POST to /v1/systemone and returns structured Response with latency' do
      fake_body = {
        model: 'jev-latest',
        answers: {
          is_safe: { type: 'noul', noul: 0.98 },
          complexity: { type: 'choice', choice: 'simple', confidence: 0.95 }
        },
        usage: { input_tokens: 120, output_tokens: 24 }
      }.to_json

      fake_http_response = instance_double(Net::HTTPSuccess, body: fake_body, code: '200')
      allow(fake_http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_http_response)

      resp = client.systemone(
        state: 'ls -la',
        questions: {
          is_safe: { type: 'noul', instructions: 'Is this shell command safe?' },
          complexity: { type: 'choice', criteria: { simple: 'Easy command', complex: 'Multi-step command' } }
        }
      )

      expect(resp).to be_a(Antigravity::Jev::Response)
      expect(resp.noul(:is_safe)).to eq(0.98)
      expect(resp.choice(:complexity)).to eq('simple')
      expect(resp.confidence(:complexity)).to eq(0.95)
      expect(resp.latency_ms).to be_a(Numeric)
      expect(resp.latency_ms).to be >= 0
    end
  end

  describe 'primitive convenience helpers' do
    let(:client) { described_class.new(mock: true) }

    it '#noul returns probability float' do
      client.set_mock_handler do |_state, _questions|
        {
          'is_safe' => { 'type' => 'noul', 'noul' => 0.85 }
        }
      end

      prob, resp = client.noul('Is this command safe?', state: 'cat README.md')
      expect(prob).to eq(0.85)
      expect(resp).to be_a(Antigravity::Jev::Response)
      expect(resp.latency_ms).to be_a(Numeric)
    end

    it '#choice returns selected category and confidence' do
      client.set_mock_handler do |_state, _questions|
        {
          'model_tier' => { 'type' => 'choice', 'choice' => 'flash', 'confidence' => 0.91 }
        }
      end

      choice, conf, = client.choice(
        { flash: 'Simple question', pro: 'Complex reasoning' },
        state: 'What is 2 + 2?'
      )
      expect(choice).to eq('flash')
      expect(conf).to eq(0.91)
    end
  end
end
