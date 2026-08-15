# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Antigravity::Diagnostics do
  describe '.summary' do
    subject(:data) { described_class.summary }

    it 'returns a hash with all expected keys' do
      expect(data).to be_a(Hash)
      expected_keys = %i[
        sdk_version ruby_version ruby_platform bundler_version rv_version
        api_key_present api_key_prefix api_key_suffix api_key_source api_key_raw
        default_model model_source
        harness_path harness_exists harness_size harness_mtime harness_arch
        timeout_llm timeout_ws timeout_handshake
        gems
      ]
      expected_keys.each do |key|
        expect(data).to have_key(key), "missing key: #{key}"
      end
    end

    it 'reports correct SDK version' do
      expect(data[:sdk_version]).to eq(Antigravity::VERSION)
    end

    it 'reports correct Ruby version' do
      expect(data[:ruby_version]).to eq(RUBY_VERSION)
    end

    it 'reports correct Ruby platform' do
      expect(data[:ruby_platform]).to eq(RUBY_PLATFORM)
    end

    it 'detects Bundler version' do
      expect(data[:bundler_version]).to eq(Bundler::VERSION)
    end

    it 'reports gems as a hash' do
      expect(data[:gems]).to be_a(Hash)
      expect(data[:gems].keys).to include('websocket', 'json', 'logger')
    end

    it 'detects stdlib gems with fallback' do
      # json and logger are stdlib — should never be nil
      expect(data[:gems]['json']).not_to be_nil
      expect(data[:gems]['logger']).not_to be_nil
    end

    it 'reports timeout values as integers' do
      expect(data[:timeout_llm]).to be_a(Integer)
      expect(data[:timeout_ws]).to be_a(Integer)
      expect(data[:timeout_handshake]).to be_a(Integer)
    end

    it 'reports default model' do
      expect(data[:default_model]).to be_a(String)
      expect(data[:default_model]).not_to be_empty
    end

    context 'with GEMINI_API_KEY set' do
      before { allow(Antigravity.config).to receive(:api_key).and_return('AIzaSyFAKEKEY123456') }

      it 'reports api_key_present as true' do
        expect(data[:api_key_present]).to be true
      end

      it 'masks the key with prefix and suffix' do
        expect(data[:api_key_prefix]).to eq('AIzaSy')
        expect(data[:api_key_suffix]).to eq('56')
      end
    end

    context 'without GEMINI_API_KEY' do
      before { allow(Antigravity.config).to receive(:api_key).and_return(nil) }

      it 'reports api_key_present as false' do
        expect(data[:api_key_present]).to be false
      end
    end
  end

  describe '.health_check' do
    it 'returns an array' do
      expect(described_class.health_check).to be_a(Array)
    end

    it 'flags missing API key' do
      data = described_class.summary.merge(api_key_present: false)
      issues = described_class.health_check(data)
      expect(issues).to include('GEMINI_API_KEY is not set')
    end

    it 'flags missing harness binary' do
      data = described_class.summary.merge(harness_exists: false, harness_path: '/fake/path')
      issues = described_class.health_check(data)
      expect(issues).to include('Harness binary not found at /fake/path')
    end

    it 'flags missing websocket gem' do
      data = described_class.summary.merge(gems: { 'websocket' => nil })
      issues = described_class.health_check(data)
      expect(issues).to include('websocket gem not loaded')
    end

    it 'returns empty when everything is fine' do
      data = described_class.summary.merge(
        api_key_present: true,
        harness_exists: true,
        gems: { 'websocket' => '1.2.11' }
      )
      issues = described_class.health_check(data)
      expect(issues).to be_empty
    end
  end

  describe '.run!' do
    it 'prints diagnostics to stdout without raising' do
      output = capture_stdout { described_class.run! }
      expect(output).to include('Antigravity SDK')
      expect(output).to include('Runtime')
      expect(output).to include('Authentication')
      expect(output).to include('Harness')
      expect(output).to include('Dependencies')
      expect(output).to include('Timeouts')
    end

    it 'returns the summary hash' do
      result = capture_stdout { @data = described_class.run! }
      expect(@data).to be_a(Hash)
      expect(@data[:sdk_version]).to eq(Antigravity::VERSION)
    end
  end

  # Helper to capture stdout
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
