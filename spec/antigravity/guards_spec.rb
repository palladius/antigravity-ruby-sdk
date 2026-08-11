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
      ENV.delete("RACK_ENV")
    end

    it "automagically logs agent prompts, responses, and tool calls with emojis to specified log file" do
      agent = Antigravity::Agent.new(auto_logger: false)
      agent.attach_logger(tmp_log, silent_notice: true)
      agent.register_tool("ping", description: "Pings server") { "pong" }

      agent.ask("Run ping")

      expect(File.exist?(tmp_log)).to be true
      log_content = File.read(tmp_log, encoding: "UTF-8")
      expect(log_content).to include("💬 [Antigravity::Prompt] User: 'Run ping'")
      expect(log_content).to include("🤖 [Antigravity::Response] Assistant (#{Antigravity.config.default_model}):")
      expect(log_content).to include("🛠️ [Antigravity::Tool] Executing 'ping'")
      expect(log_content).to include("📦 [Antigravity::Tool] Result for 'ping': pong")
    end

    it "prints startup notice '🪵 Logging to ...' when logger is attached" do
      expect {
        Antigravity::Agent.new(model: "gemini-flash-latest", auto_logger: false).attach_logger(tmp_log)
      }.to output(/🪵 Logging to tmp\/test_logs\/custom_agent\.log/).to_stdout
    end

    context "when Rails.logger is defined" do
      before do
        fake_rails = Class.new do
          def self.logger
            @logger ||= ::Logger.new(IO::NULL)
          end
        end
        stub_const("Rails", fake_rails)
      end

      it "automatically attaches Rails.logger and prints notice" do
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("Rails.logger")
          expect(agent.logger_guard.logger).to eq(Rails.logger)
        }.to output(/🪵 Logging to Rails\.logger/).to_stdout
      end
    end

    context "when ANTIGRAVITY_LOGGER is set" do
      %w[false 0 none no].each do |env_val|
        it "suppresses automagic logger when ANTIGRAVITY_LOGGER='#{env_val}'" do
          ENV["ANTIGRAVITY_LOGGER"] = env_val
          expect {
            agent = Antigravity::Agent.new
            expect(agent.logger_guard).to be_nil
          }.not_to output(/🪵 Logging to/).to_stdout
        end
      end

      it "enables automagic logger when ANTIGRAVITY_LOGGER='true'" do
        ENV["ANTIGRAVITY_LOGGER"] = "true"
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard).not_to be_nil
        }.to output(/🪵 Logging to log\/antigravity\.log/).to_stdout

        FileUtils.rm_f("log/antigravity.log")
      end
    end

    context "when environment variables dictate log path" do
      it "uses log/production.log when RAILS_ENV='production'" do
        ENV["RAILS_ENV"] = "production"
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/production.log")
        }.to output(/🪵 Logging to log\/production\.log/).to_stdout

        FileUtils.rm_f("log/production.log")
      end

      it "uses log/staging.log when RACK_ENV='staging'" do
        ENV["RACK_ENV"] = "staging"
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/staging.log")
        }.to output(/🪵 Logging to log\/staging\.log/).to_stdout

        FileUtils.rm_f("log/staging.log")
      end

      it "defaults to log/antigravity.log when no environment variables are set" do
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/antigravity.log")
        }.to output(/🪵 Logging to log\/antigravity\.log/).to_stdout

        FileUtils.rm_f("log/antigravity.log")
      end
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
