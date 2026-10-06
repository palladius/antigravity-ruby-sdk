# frozen_string_literal: true

require "spec_helper"
require "antigravity/jev"
require "antigravity/jev/telemetry"

RSpec.describe Antigravity::Jev::Telemetry do
  describe ".format_command_verdict" do
    it "formats approved line" do
      line = described_class.format_command_verdict(
        :allow,
        "ls -la",
        latency_ms: 75.0,
        probability: 0.992,
        color: false
      )
      expect(line).to eq("⚡ [Jev: 75.0ms | Safe: 99.2%] ✅ APPROVED: ls -la")
    end

    it "formats unsure line" do
      line = described_class.format_command_verdict(
        :ask,
        "cat .env",
        latency_ms: 88.0,
        probability: 0.524,
        color: false
      )
      expect(line).to eq("⚡ [Jev: 88.0ms | Safe: 52.4%] ⚠️ UNSURE: cat .env")
    end

    it "formats blocked line" do
      line = described_class.format_command_verdict(
        :deny,
        "rm -rf /",
        latency_ms: 64.0,
        probability: 0.011,
        color: false
      )
      expect(line).to eq("⚡ [Jev: 64.0ms | Safe: 1.1%] 🚫 BLOCKED: rm -rf /")
    end
  end

  describe ".format_routing" do
    it "formats routing decision line for simple tier" do
      line = described_class.format_routing(
        "simple",
        "gemini-2.5-flash",
        latency_ms: 92.0,
        confidence: 0.95,
        color: false
      )
      expect(line).to eq("⚡ [Jev: 92.0ms | Routing: simple (95.0%)] 🚀 ROUTED: gemini-2.5-flash")
    end

    it "formats routing decision line for complex tier" do
      line = described_class.format_routing(
        "complex",
        "gemini-2.5-pro",
        latency_ms: 120.0,
        confidence: 0.88,
        color: false
      )
      expect(line).to eq("⚡ [Jev: 120.0ms | Routing: complex (88.0%)] 🧠 ROUTED: gemini-2.5-pro")
    end
  end
end
