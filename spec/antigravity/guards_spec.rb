# frozen_string_literal: true

require "spec_helper"
require "logger"
require "json"

RSpec.describe Antigravity::Guards do
  describe Antigravity::Guards::AgentLogger do
    let(:tmp_dir) { "tmp/test_logs" }
    let(:tmp_log) { "#{tmp_dir}/custom_agent.jsonl" }
    let(:tmp_compact) { "#{tmp_dir}/custom_agent.log" }

    after do
      FileUtils.rm_rf(tmp_dir)
      ENV.delete("ANTIGRAVITY_LOGGER")
      ENV.delete("RAILS_ENV")
      ENV.delete("RACK_ENV")
    end

    it "writes structured JSONL to primary log and compact one-liners to .log" do
      agent = Antigravity::Agent.new(auto_logger: false)
      agent.attach_logger(tmp_log, silent_notice: true)
      agent.register_tool("ping", description: "Pings server") { "pong" }

      response = agent.ask("Run ping")
      puts "DEBUG RESPONSE: #{response.inspect}"

      # JSONL log: structured events
      expect(File.exist?(tmp_log)).to be true
      lines = File.readlines(tmp_log, chomp: true).map { |l| JSON.parse(l, symbolize_names: true) }
      events = lines.map { |l| l[:event] }
      expect(events).to include('prompt', 'response', 'tool_call', 'tool_result')
      expect(lines.find { |l| l[:event] == 'prompt' }[:user_input]).to eq('Run ping')

      # Compact log: human-readable one-liners with byte sizes
      expect(File.exist?(tmp_compact)).to be true
      compact = File.read(tmp_compact, encoding: "UTF-8")
      expect(compact).to include("PROMPT")
      expect(compact).to include("RESPONSE")
      expect(compact).to include("TOOL_CALL ping")
      expect(compact).to include("TOOL_RESULT ping OK")
    end

    it "prints startup notice '🪵 Logging to ...' when logger is attached" do
      expect {
        Antigravity::Agent.new(model: "gemini-flash-latest", auto_logger: false).attach_logger(tmp_log)
      }.to output(/🪵 Logging to tmp\/test_logs\/custom_agent\.jsonl/).to_stdout
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
        }.to output(/🪵 Logging to log\/antigravity\.jsonl/).to_stdout

        FileUtils.rm_f("log/antigravity.jsonl")
        FileUtils.rm_f("log/antigravity.log")
      end
    end

    context "when environment variables dictate log path" do
      it "uses log/production.jsonl when RAILS_ENV='production'" do
        ENV["RAILS_ENV"] = "production"
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/production.jsonl")
        }.to output(/🪵 Logging to log\/production\.jsonl/).to_stdout

        FileUtils.rm_f("log/production.jsonl")
        FileUtils.rm_f("log/production.log")
      end

      it "uses log/staging.jsonl when RACK_ENV='staging'" do
        ENV["RACK_ENV"] = "staging"
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/staging.jsonl")
        }.to output(/🪵 Logging to log\/staging\.jsonl/).to_stdout

        FileUtils.rm_f("log/staging.jsonl")
        FileUtils.rm_f("log/staging.log")
      end

      it "defaults to log/antigravity.jsonl when no environment variables are set" do
        expect {
          agent = Antigravity::Agent.new
          expect(agent.logger_guard.target_description).to eq("log/antigravity.jsonl")
        }.to output(/🪵 Logging to log\/antigravity\.jsonl/).to_stdout

        FileUtils.rm_f("log/antigravity.jsonl")
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
