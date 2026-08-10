# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Agent do
  subject(:agent) do
    described_class.new(model: "gemini-2.5-flash") do |a|
      a.system_instruction = "You are a helpful test agent"
    end
  end

  it "initializes with model and system instruction" do
    expect(agent.model).to eq("gemini-2.5-flash")
    expect(agent.system_instruction).to eq("You are a helpful test agent")
  end

  it "registers dynamic block tools" do
    tool = agent.register_tool("calculator", description: "Performs math") do |params|
      "Result: 42"
    end

    expect(tool.tool_name).to eq("calculator")
    expect(agent.tools.count).to eq(1)
  end

  it "streams response chunks matching RubyLLM semantics" do
    chunks = []
    final_message = agent.prompt("Hello world") do |chunk|
      chunks << chunk
    end

    expect(chunks.any?).to be true
    expect(chunks.first).to be_a(Antigravity::Chunk)
    expect(final_message).to be_a(Antigravity::Message)
    expect(final_message.content).to include("Hello!")
  end
end
