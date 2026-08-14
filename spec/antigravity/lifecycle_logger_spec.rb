# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::LifecycleLogger do
  let(:hooks) { Antigravity::Hooks.new }
  let(:agent) do
    instance_double(
      Antigravity::Agent,
      hooks: hooks,
      model: "gemini-3.6-flash",
      turn_count: 2,
      session_summary: {
        conversation_id: "abc123def456",
        turn_count: 2,
        total_tokens: 31553,
        prompt_tokens: 12000,
        candidates_tokens: 19553,
        model: "gemini-3.6-flash"
      }
    )
  end

  # Stub agent's hook delegation methods to forward to hooks
  before do
    allow(agent).to receive(:before_prompt) { |&blk| hooks.before_prompt(&blk) }
    allow(agent).to receive(:after_response) { |&blk| hooks.after_response(&blk) }
  end

  describe ".status_line" do
    it "formats a compact status string with turns, tokens, model, and conv_id" do
      line = described_class.status_line(agent)
      expect(line).to include("T2")
      expect(line).to include("31.6k")  # 31553 -> 31.6k
      expect(line).to include("gemini-3.6-flash")
      expect(line).to include("abc123de")  # first 8 chars of conv_id
    end

    it "shows raw count for tokens under 1000" do
      allow(agent).to receive(:session_summary).and_return(
        total_tokens: 500, model: "test", conversation_id: "x"
      )
      line = described_class.status_line(agent)
      expect(line).to include("500")
    end

    it "includes the coin emoji" do
      line = described_class.status_line(agent)
      expect(line).to include("\u{1FA99}") # 🪙
    end

    it "handles missing session_summary gracefully" do
      allow(agent).to receive(:session_summary).and_raise(RuntimeError)
      allow(agent).to receive(:turn_count).and_raise(RuntimeError)
      # Should not raise
      expect { described_class.status_line(agent) }.not_to raise_error
    end
  end

  describe ".attach!" do
    it "subscribes to session_start, session_end, tool, and turn hooks" do
      described_class.attach!(agent)

      # session_start hook fires
      output = capture_stdout { hooks.emit(:session_start, { model: "test", conversation_id: "abc" }) }
      expect(output).to include("session_start")

      # session_end hook fires
      allow(agent).to receive(:turn_count).and_return(3)
      output = capture_stdout { hooks.emit(:session_end, { turn_count: 3 }) }
      expect(output).to include("session_end")
      expect(output).to include("3 turns")
    end

    it "fires pre_turn on before_prompt" do
      described_class.attach!(agent)

      output = capture_stdout { hooks.run_pre_prompt("What is Ruby?") }
      expect(output).to include("pre_turn")
      expect(output).to include("What is Ruby?")
    end

    it "fires post_turn on after_response with byte count" do
      described_class.attach!(agent)

      response = Antigravity::Message.new(
        content: "Ruby is great!",
        role: :assistant,
        thinking: "Let me think about this"
      )

      output = capture_stdout { hooks.run_post_response(response) }
      expect(output).to include("post_turn")
      expect(output).to include("14B")   # "Ruby is great!".length == 14
      expect(output).to include("think") # thinking content present
    end

    it "fires tool_call and tool_blocked events" do
      described_class.attach!(agent)

      output = capture_stdout do
        hooks.emit(:tool_call, { tool_name: "list_dir", params: { path: "/tmp" } })
      end
      expect(output).to include("tool_call")
      expect(output).to include("list_dir")

      output = capture_stdout do
        hooks.emit(:tool_blocked, { tool: "run_command", reason: "rm detected" })
      end
      expect(output).to include("tool_deny")
      expect(output).to include("rm detected")
    end

    it "fires tool_error events" do
      described_class.attach!(agent)

      output = capture_stdout do
        hooks.emit(:tool_error, { tool_name: "write_file", error: "Permission denied" })
      end
      expect(output).to include("tool_error")
      expect(output).to include("Permission denied")
    end
  end

  describe "verbose mode" do
    it "prints response preview when verbose" do
      described_class.attach!(agent, verbose: true)

      response = Antigravity::Message.new(content: "Hello world!", role: :assistant)
      output = capture_stdout { hooks.run_post_response(response) }
      expect(output).to include("Hello world!")
    end

    it "does NOT print response preview when not verbose" do
      described_class.attach!(agent, verbose: false)

      response = Antigravity::Message.new(content: "Hello world!", role: :assistant)
      output = capture_stdout { hooks.run_post_response(response) }
      # The content preview should not appear (only the stats line)
      expect(output).not_to include('"Hello world!"')
    end
  end
end

RSpec.describe Antigravity::Colors do
  describe ".colorize" do
    it "wraps text with ANSI codes when stdout is a TTY" do
      allow($stdout).to receive(:tty?).and_return(true)
      result = described_class.colorize("hello", :green)
      expect(result).to eq("\e[32mhello\e[0m")
    end

    it "returns plain text when stdout is NOT a TTY" do
      allow($stdout).to receive(:tty?).and_return(false)
      result = described_class.colorize("hello", :green)
      expect(result).to eq("hello")
    end

    it "composes multiple styles" do
      allow($stdout).to receive(:tty?).and_return(true)
      result = described_class.colorize("hello", :bold, :red)
      expect(result).to eq("\e[1m\e[31mhello\e[0m")
    end
  end

  # Shortcut methods
  %i[gray dim green yellow red cyan blue magenta bold].each do |color|
    describe ".#{color}" do
      it "returns a string" do
        allow($stdout).to receive(:tty?).and_return(true)
        expect(described_class.send(color, "test")).to be_a(String)
      end
    end
  end
end

# Helper to capture stdout
def capture_stdout
  original = $stdout
  $stdout = StringIO.new
  # Force tty? to false so ANSI codes don't wrap (cleaner assertions)
  allow($stdout).to receive(:tty?).and_return(false)
  yield
  $stdout.string
ensure
  $stdout = original
end
