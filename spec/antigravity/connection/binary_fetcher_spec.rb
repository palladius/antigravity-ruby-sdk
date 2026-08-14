# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Connection::BinaryFetcher do
  describe ".extract_binary" do
    it "raises HarnessNotFoundError when unzip command fails" do
      allow(described_class).to receive(:system).with('unzip', any_args).and_return(false)

      Dir.mktmpdir do |dir|
        wheel = File.join(dir, "test.whl")
        File.write(wheel, "dummy")
        expect {
          described_class.send(:extract_binary, wheel)
        }.to raise_error(Antigravity::HarnessNotFoundError, /unzip/)
      end
    end
  end
end
