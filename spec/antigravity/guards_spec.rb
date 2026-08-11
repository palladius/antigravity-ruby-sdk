# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Guards do
  describe Antigravity::Guards::AgentLogger do
    let(:tmp_dir) { "tmp/test_logs" }
    let(:tmp_log) { "#{tmp_dir}/custom_agent.log" }

    after do
      FileUtils.rm_rf(tmp_dir)
      ENV.delete("ANTIGRAVITY_LOGGER")
      ENV.delete("RAILS_ENV")
    end

    it "automagically logs agent prompts, responses, and tool calls to specified log file" do
      agent = Antigravity::Agent.new(auto_logger: false)
      agent.attach_logger(tmp_log, silent_notice: true)
      agent.register_tool("ping", description: "Pings server") { "pong" }

      agent.ask("Run ping")

      expect(File.exist?(tmp_log)).to be true
      log_content = File.read(tmp_log)
      expect(log_content).to include("[Antigravity::Prompt] User: 'Run ping'")
      expect(log_content).to include("[Antigravity::Response] Assistant (gemini-flash-latest):")
    end

    it "prints startup notice '🪵 Logging to ...' when logger is attached" do
      expect {
        Antigravity::Agent.new(model: "gemini-flash-latest", auto_logger: false).attach_logger(tmp_log)
      }.to output(/🪵 Logging to tmp\/test_logs\/custom_agent\.log/).to_stdout
    end

    it "suppresses automagic logger when ENV['ANTIGRAVITY_LOGGER'] is false" do
      ENV["ANTIGRAVITY_LOGGER"] = "false"
      expect {
        agent = Antigravity::Agent.new
        expect(agent.logger_guard).to be_nil
      }.not_to output(/🪵 Logging to/).to_stdout
    end

    it "uses log/RAILS_ENV.log when ENV['RAILS_ENV'] is set" do
      ENV["RAILS_ENV"] = "test_environment"
      expect {
        agent = Antigravity::Agent.new(auto_logger: false)
        guard = agent.attach_logger
        expect(guard.target_description).to eq("log/test_environment.log")
      }.to output(/🪵 Logging to log\/test_environment\.log/).to_stdout

      FileUtils.rm_f("log/test_environment.log")
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
