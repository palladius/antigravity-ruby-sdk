# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Antigravity Emojis" do
  it "returns central emojis via Antigravity.emoji" do
    expect(Antigravity.emoji(:gem)).to eq("💎")
    expect(Antigravity.emoji(:tool)).to eq("🛠️")
    expect(Antigravity.emoji(:sidecar)).to eq("🚗")
    expect(Antigravity.emoji(:prompt)).to eq("💬")
    expect(Antigravity.emoji(:response)).to eq("🤖")
    expect(Antigravity.emoji(:thinking)).to eq("🤔")
    expect(Antigravity.emoji(:logger)).to eq("🪵")
    expect(Antigravity.emoji(:unknown)).to eq("💎")
  end

  it "exposes .emoji methods on core classes" do
    expect(Antigravity::Agent.emoji).to eq("💎")
    expect(Antigravity::Tool.emoji).to eq("🛠️")
    expect(Antigravity::Sidecar::Base.emoji).to eq("🚗")
    expect(Antigravity::Skill.emoji).to eq("📁")
  end

  it "exposes #emoji method on class instances" do
    agent = Antigravity::Agent.new(auto_logger: false)
    expect(agent.emoji).to eq("💎")

    msg_user = Antigravity::Message.new(role: :user)
    expect(msg_user.emoji).to eq("💬")

    msg_assistant = Antigravity::Message.new(role: :assistant)
    expect(msg_assistant.emoji).to eq("🤖")
  end
end
