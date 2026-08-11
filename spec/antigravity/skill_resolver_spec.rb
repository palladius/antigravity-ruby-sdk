# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::SkillResolver do
  let(:fixtures) { File.expand_path("../../fixtures/skills", __FILE__) }

  describe ".skill_dir?" do
    it "returns true for a dir with SKILL.md" do
      expect(described_class.skill_dir?(File.join(fixtures, "single-skill"))).to be true
    end

    it "returns false for a dir without SKILL.md" do
      expect(described_class.skill_dir?(File.join(fixtures, "multi-skills/skills/not-a-skill"))).to be false
    end

    it "returns false for a non-directory" do
      expect(described_class.skill_dir?("/dev/null")).to be false
    end
  end

  describe ".resolve" do
    context "with a single skill directory" do
      it "returns the skill path in an array" do
        result = described_class.resolve(File.join(fixtures, "single-skill"))
        expect(result).to eq([File.expand_path(File.join(fixtures, "single-skill"))])
      end
    end

    context "with a container that has skills/ subfolder" do
      it "discovers all valid skills inside skills/" do
        result = described_class.resolve(File.join(fixtures, "multi-skills"))
        names = result.map { |p| File.basename(p) }
        expect(names).to contain_exactly("skill-alpha", "skill-beta")
        expect(names).not_to include("not-a-skill")
      end
    end

    context "with a flat container (no skills/ subfolder)" do
      it "discovers skills directly in the directory" do
        result = described_class.resolve(File.join(fixtures, "flat-skills"))
        names = result.map { |p| File.basename(p) }
        expect(names).to contain_exactly("skill-delta", "skill-gamma")
      end
    end

    context "with an invalid path" do
      it "raises for non-existent path" do
        expect {
          described_class.resolve("/totally/bogus/path/to/nowhere")
        }.to raise_error(ArgumentError, /does not exist/)
      end

      it "raises for a file (not directory)" do
        expect {
          described_class.resolve(__FILE__)
        }.to raise_error(ArgumentError, /not a directory/)
      end

      it "raises for a dir with no skills" do
        Dir.mktmpdir("empty-skills") do |dir|
          expect {
            described_class.resolve(dir)
          }.to raise_error(ArgumentError, /No skills found/)
        end
      end
    end
  end

  describe ".discover" do
    it "finds skills in a container with skills/ subfolder" do
      result = described_class.discover(File.join(fixtures, "multi-skills"))
      expect(result.size).to eq(2)
      expect(result.all? { |p| File.exist?(File.join(p, "SKILL.md")) }).to be true
    end

    it "finds skills in a flat container" do
      result = described_class.discover(File.join(fixtures, "flat-skills"))
      expect(result.size).to eq(2)
    end

    it "returns empty array for non-existent path" do
      expect(described_class.discover("/does/not/exist")).to eq([])
    end

    it "returns sorted results" do
      result = described_class.discover(File.join(fixtures, "flat-skills"))
      expect(result).to eq(result.sort)
    end
  end

  describe ".github_url?" do
    it "recognizes GitHub URLs" do
      expect(described_class.github_url?("https://github.com/org/repo")).to be true
      expect(described_class.github_url?("https://github.com/org/repo/tree/main/skills")).to be true
      expect(described_class.github_url?("http://github.com/org/repo")).to be true
    end

    it "rejects non-GitHub URLs" do
      expect(described_class.github_url?("/local/path")).to be false
      expect(described_class.github_url?("~/my-skills")).to be false
      expect(described_class.github_url?("https://gitlab.com/org/repo")).to be false
    end
  end
end
