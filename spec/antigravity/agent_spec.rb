# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Agent do
  subject(:agent) do
    described_class.new do |a|
      a.system_instruction = "You are a helpful test agent"
    end
  end

  it "initializes with sensible default model and system instruction" do
    expect(agent.model).to eq(Antigravity.config.default_model)
    expect(agent.system_instruction).to eq("You are a helpful test agent")
  end

  it "registers dynamic block tools" do
    tool = agent.register_tool("calculator", description: "Performs math") do |_params|
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
    expect(final_message.content).to include(Antigravity.config.default_model)
  end

  # --- Skills ---

  let(:fixtures) { File.expand_path("../../fixtures/skills", __FILE__) }

  context "skills at construction" do
    it "loads skills from constructor via skills: array" do
      a = described_class.new(skills: [File.join(fixtures, "single-skill")], auto_logger: false)
      expect(a.skills.size).to eq(1)
      expect(a.skills.first.name).to eq("pirate-coder")
    end

    it "discovers container skills from constructor" do
      a = described_class.new(skills: [File.join(fixtures, "multi-skills")], auto_logger: false)
      expect(a.skills.size).to eq(2)
      names = a.skills.map(&:name)
      expect(names).to include("samurai-reviewer", "french-chef-debugger")
    end
  end

  context "skills at runtime" do
    it "adds a single skill with add_skill" do
      agent.add_skill(File.join(fixtures, "single-skill"))
      expect(agent.skills.size).to eq(1)
      expect(agent.skills.first.name).to eq("pirate-coder")
    end

    it "adds multiple skills with add_skills" do
      agent.add_skills([
        File.join(fixtures, "single-skill"),
        File.join(fixtures, "flat-skills")
      ])
      expect(agent.skills.size).to eq(3)  # 1 single + 2 flat
    end

    it "raises on add_skill when path resolves to multiple" do
      expect {
        agent.add_skill(File.join(fixtures, "multi-skills"))
      }.to raise_error(ArgumentError, /Use add_skills instead/)
    end

    it "deduplicates skills by path" do
      2.times { agent.add_skill(File.join(fixtures, "single-skill")) }
      expect(agent.skills.size).to eq(1)
    end

    it "supports inline skills" do
      agent.add_inline_skill(
        name: "test-inline",
        description: "An inline test",
        instructions: "Just do it!"
      )
      expect(agent.skills.size).to eq(1)
      expect(agent.skills.first.path).to be_nil
    end
  end

  context "harness config wiring" do
    it "includes skillsPaths in harness config" do
      a = described_class.new(
        skills: [File.join(fixtures, "single-skill")],
        auto_logger: false
      )
      config = a.send(:build_harness_config)
      expect(config[:config][:skillsPaths]).to be_an(Array)
      expect(config[:config][:skillsPaths].first).to end_with("single-skill")
    end

    it "omits skillsPaths when no skills are loaded" do
      a = described_class.new(auto_logger: false)
      config = a.send(:build_harness_config)
      expect(config[:config]).not_to have_key(:skillsPaths)
    end

    it "excludes inline skills from skillsPaths (they have no path)" do
      a = described_class.new(auto_logger: false)
      a.add_inline_skill(name: "inline", description: "test", instructions: "do it")
      config = a.send(:build_harness_config)
      # Inline skills have nil path, so skillsPaths should be empty
      expect(config[:config]).not_to have_key(:skillsPaths)
    end
  end

  context "class methods" do
    it "lists skills in a container" do
      paths = described_class.list_skills(File.join(fixtures, "flat-skills"))
      expect(paths.size).to eq(2)
      expect(paths.map { |p| File.basename(p) }).to contain_exactly("skill-delta", "skill-gamma")
    end
  end
end
