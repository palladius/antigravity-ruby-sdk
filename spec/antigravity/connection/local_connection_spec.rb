# frozen_string_literal: true

# Tests for binary discovery — finding the localharness binary.
# These are UNIT tests (mock filesystem) — no harness needed.

RSpec.describe Antigravity::Connection::LocalConnection do
  describe '.find_binary!' do
    it 'discovers localharness from ANTIGRAVITY_HARNESS_PATH env var' do
      with_env('ANTIGRAVITY_HARNESS_PATH' => '/usr/local/bin/fake-harness') do
        allow(File).to receive(:executable?).with('/usr/local/bin/fake-harness').and_return(true)
        expect(described_class.find_binary!).to eq('/usr/local/bin/fake-harness')
      end
    end

    it 'discovers localharness from ~/.antigravity/bin' do
      harness_binary = File.expand_path('~/.antigravity/bin/localharness')
      with_env('ANTIGRAVITY_HARNESS_PATH' => nil) do
        allow(File).to receive(:executable?).and_return(false)
        allow(File).to receive(:executable?).with(harness_binary).and_return(true)
        expect(described_class.find_binary!).to include('localharness')
      end
    end

    it 'raises HarnessNotFoundError when binary is completely missing' do
      with_env('ANTIGRAVITY_HARNESS_PATH' => nil, 'ANTIGRAVITY_AUTO_DOWNLOAD' => 'false') do
        allow(File).to receive(:executable?).and_return(false)
        allow(described_class).to receive(:`).and_return('')  # which returns empty

        expect {
          described_class.find_binary!
        }.to raise_error(Antigravity::HarnessNotFoundError, /localharness/)
      end
    end
  end

  # Helper to temporarily override ENV
  def with_env(overrides, &block)
    old_values = {}
    overrides.each do |key, val|
      old_values[key] = ENV[key]
      if val.nil?
        ENV.delete(key)
      else
        ENV[key] = val
      end
    end
    yield
  ensure
    old_values.each { |key, val| val.nil? ? ENV.delete(key) : ENV[key] = val }
  end
end
