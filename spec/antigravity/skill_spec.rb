# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Skill do
  let(:fixtures) { File.expand_path("../../fixtures/skills", __FILE__) }

  describe ".load" do
    it "loads a skill from a directory with SKILL.md and YAML frontmatter" do
      skill = described_class.load(File.join(fixtures, "single-skill"))
      expect(skill.name).to eq("pirate-coder")
      expect(skill.description).to include("pirate speak")
      expect(skill.instructions).to include("salty sea-dog")
      expect(skill.path).to end_with("single-skill")
    end

    it "loads the built-in repository skill using-antigravity-ruby-sdk" do
      sdk_skill_path = File.expand_path("../../skills/using-antigravity-ruby-sdk", __dir__)
      skill = described_class.load(sdk_skill_path)
      expect(skill.name).to eq("using-antigravity-ruby-sdk")
      expect(skill.description).to include("Antigravity Ruby SDK")
      expect(skill.instructions).to include("Core Concepts & Architecture")
    end

    it "raises when SKILL.md is missing" do
      expect {
        described_class.load(File.join(fixtures, "multi-skills/skills/not-a-skill"))
      }.to raise_error(ArgumentError, /SKILL\.md not found/)
    end

    it "falls back to directory basename when frontmatter is missing" do
      Dir.mktmpdir("no-frontmatter") do |dir|
        File.write(File.join(dir, "SKILL.md"), "# Just instructions, no YAML")
        skill = described_class.load(dir)
        expect(skill.name).to eq(File.basename(dir))
        expect(skill.description).to eq("")
        expect(skill.instructions).to eq("# Just instructions, no YAML")
      end
    end

    it "raises ArgumentError when YAML frontmatter has syntax errors" do
      Dir.mktmpdir("invalid-frontmatter") do |dir|
        File.write(File.join(dir, "SKILL.md"), "---\ninvalid: : : yaml\n---\nBody")
        expect {
          described_class.load(dir)
        }.to raise_error(ArgumentError, /Invalid YAML frontmatter in/)
      end
    end
  end

  describe ".inline" do
    it "creates a skill without a file" do
      skill = described_class.inline(
        name: "inline-demo",
        description: "A test inline skill",
        instructions: "Do the thing!"
      )
      expect(skill.name).to eq("inline-demo")
      expect(skill.description).to eq("A test inline skill")
      expect(skill.instructions).to eq("Do the thing!")
      expect(skill.path).to be_nil
    end
  end

  describe ".skill_dir?" do
    it "returns true for a directory with SKILL.md" do
      expect(described_class.skill_dir?(File.join(fixtures, "single-skill"))).to be true
    end

    it "returns false for a directory without SKILL.md" do
      expect(described_class.skill_dir?(File.join(fixtures, "multi-skills/skills/not-a-skill"))).to be false
    end

    it "returns false for a non-existent path" do
      expect(described_class.skill_dir?("/totally/fake/path")).to be false
    end
  end

  describe "#to_s and #inspect" do
    it "produces readable output" do
      skill = described_class.load(File.join(fixtures, "single-skill"))
      expect(skill.to_s).to include("pirate-coder")
      expect(skill.inspect).to include("pirate speak")
    end
  end
end
