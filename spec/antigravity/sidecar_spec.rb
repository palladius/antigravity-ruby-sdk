# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Sidecar do
  describe Antigravity::Sidecar::AuditLogger do
    let(:tmp_log) { "tmp/test_audit.jsonl" }
    subject(:logger) { described_class.new(tmp_log) }

    after do
      logger.stop!
      FileUtils.rm_f(tmp_log)
    end

    it "emits and logs audit events asynchronously" do
      logger.emit(:test_event, { user: "ricc" })
      sleep 0.1 # allow sidecar worker thread to process

      expect(File.exist?(tmp_log)).to be true
      content = File.read(tmp_log)
      expect(content).to include("test_event")
      expect(content).to include("ricc")
    end
  end
end
