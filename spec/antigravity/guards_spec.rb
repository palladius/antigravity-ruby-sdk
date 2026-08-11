# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Guards do
  describe Antigravity::Guards::AgentLogger do
    let(:tmp_log) { "tmp/test_agent_logger.log" }
    subject(:agent) { Antigravity::Agent.new }

    after do
      FileUtils.rm_f(tmp_log)
    end

    it "logs agent prompts, responses, and tool calls to specified log file" do
      agent.attach_logger(tmp_log)
      agent.register_tool("ping", description: "Pings server") { "pong" }

      agent.ask("Run ping")

      expect(File.exist?(tmp_log)).to be true
      log_content = File.read(tmp_log)
      expect(log_content).to include("[Antigravity::Prompt] User: 'Run ping'")
      expect(log_content).to include("[Antigravity::Response] Assistant (gemini-flash-latest):")
    end
  end

  describe Antigravity::Guards::FileProtection do
    it "blocks default protected files (.env, Gemfile)" do
      guard = described_class.new
      result = guard.call("write_file", { path: ".env" })
      expect(result[:status]).to eq(:deny)
      expect(result[:reason]).to include("FileProtection Guard")
    end

    it "allows custom file list" do
      guard = described_class.new(files: ["custom.key"])
      expect(guard.call("write_file", { path: ".env" })).to eq(:allow)
      expect(guard.call("write_file", { path: "custom.key" })[:status]).to eq(:deny)
    end
  end

  describe Antigravity::Guards::SecretMasker do
    it "redacts secret keys with custom replacement" do
      masker = described_class.new(replacement: "🔒[SECRET]")
      output = masker.call("get_key", {}, "KEY=AIzaSyA12345678901234567890123456789012")
      expect(output).to include("🔒[SECRET]")
      expect(output).not_to include("AIzaSy")
    end
  end
end
