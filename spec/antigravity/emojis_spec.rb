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
  end

  it "returns 🤷 shrug for unknown keys" do
    expect(Antigravity.emoji(:unknown)).to eq("🤷")
    expect(Antigravity.emoji(:nope_never_heard_of_it)).to eq("🤷")
  end

  it "exposes .emoji methods on core classes via Base inheritance" do
    expect(Antigravity::Agent.emoji).to eq("🕵️‍♂️")
    expect(Antigravity::Tool.emoji).to eq("🛠️")
    expect(Antigravity::Sidecar::Runner.emoji).to eq("🚗")
    expect(Antigravity::Sidecar::Base.emoji).to eq("🚗") # backward-compat alias
    expect(Antigravity::Skill.emoji).to eq("📁")
  end

  it "exposes #emoji method on class instances" do
    agent = Antigravity::Agent.new(auto_logger: false)
    expect(agent.emoji).to eq("🕵️‍♂️")

    msg_user = Antigravity::Message.new(role: :user)
    expect(msg_user.emoji).to eq("💬")

    msg_assistant = Antigravity::Message.new(role: :assistant)
    expect(msg_assistant.emoji).to eq("🤖")
  end

  it "automagically provides emoji to any Antigravity::Base subclass" do
    # Dynamic subclass gets 🤷 by default (not in EMOJI_CLASS_MAP)
    custom_class = Class.new(Antigravity::Base)
    expect(custom_class.emoji).to eq("🤷")
    expect(custom_class.new.emoji).to eq("🤷")
  end

  it "all core classes inherit from Antigravity::Base" do
    expect(Antigravity::Agent.superclass).to eq(Antigravity::Base)
    expect(Antigravity::Tool.superclass).to eq(Antigravity::Base)
    expect(Antigravity::Skill.superclass).to eq(Antigravity::Base)
    expect(Antigravity::Message.superclass).to eq(Antigravity::Base)
    expect(Antigravity::Sidecar::Runner.superclass).to eq(Antigravity::Base)
  end
end
