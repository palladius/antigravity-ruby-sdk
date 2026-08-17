# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Riccardo Policy & Gemini Config Importer" do
  describe "Policy.preset(:riccardo)" do
    let(:policy) { Antigravity::Policy.preset(:riccardo) }

    it "allows common dev commands like gcloud and kubectl" do
      expect(policy.evaluate(:run_command, { command_line: "gcloud auth list" })[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: "kubectl get pods" })[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: "just test" })[:status]).to eq(:allow)
    end

    it "denies reading or writing .env files" do
      expect(policy.evaluate(:read_file, { target_file: ".env" })[:status]).to eq(:deny)
      expect(policy.evaluate(:write_to_file, { target_file: ".env.production" })[:status]).to eq(:deny)
    end

    it "confirms destructive commands like rm -rf" do
      expect(policy.evaluate(:run_command, { command_line: "rm -rf /tmp/test" })[:status]).to eq(:deny)
    end
  end

  describe "Policy.from_gemini_config" do
    it "imports auto-approved permissions from Gemini config.json" do
      tmp_config = Tempfile.new(["config", ".json"])
      tmp_config.write({
        "autoApprovedPermissions" => [
          "unsandboxed(gcloud container)",
          "read_file(/Users/ricc/git/personal)",
          "write_file(/Users/ricc/git/justfile)"
        ]
      }.to_json)
      tmp_config.close

      imported = Antigravity::Policy.from_gemini_config(tmp_config.path)
      expect(imported.evaluate(:run_command, { command_line: "gcloud container clusters list" })[:status]).to eq(:allow)
      expect(imported.evaluate(:read_file, { path: "/Users/ricc/git/personal" })[:status]).to eq(:allow)
      expect(imported.evaluate(:write_file, { path: "/Users/ricc/git/justfile" })[:status]).to eq(:allow)
    ensure
      tmp_config.unlink
    end

    it "respects the limit argument for gradual adoption" do
      tmp_config = Tempfile.new(["config", ".json"])
      tmp_config.write({
        "autoApprovedPermissions" => [
          "unsandboxed(gcloud)",
          "read_file(/Users/ricc/git/personal)",
          "write_file(/Users/ricc/git/justfile)"
        ]
      }.to_json)
      tmp_config.close

      imported = Antigravity::Policy.from_gemini_config(tmp_config.path, limit: 1)
      expect(imported.evaluate(:run_command, { command_line: "gcloud" })[:status]).to eq(:allow)
      expect(imported.evaluate(:read_file, { path: "/Users/ricc/git/personal" })[:status]).to eq(:deny)
    ensure
      tmp_config.unlink
    end
  end

  describe "Policy#to_ruby_dsl" do
    it "exports policy rules to valid Ruby DSL syntax string with DRY cmds/paths grouping and tilde paths" do
      home_repo = File.join(Dir.home, "git/sre")
      pol = Antigravity::Policy.define do
        allow :run_command, when: cmds("gcloud", "kubectl")
        allow :read_file, when: path(home_repo)
      end

      dsl_code = pol.to_ruby_dsl
      expect(dsl_code).to include("Antigravity.policy do")
      expect(dsl_code).to include("allow :run_command, when: cmds(")
      expect(dsl_code).to include("'gcloud'")
      expect(dsl_code).to include("'kubectl'")
      expect(dsl_code).to include("allow :read_file, when: path('~/git/sre')")
    end

    it "saves the Ruby DSL policy to a target file" do
      pol = Antigravity::Policy.define do
        allow :read_file
      end
      out_path = File.expand_path("../../tmp/test_policy.rb", __dir__)
      FileUtils.rm_f(out_path)

      saved_file = pol.save_ruby_dsl(out_path)
      expect(File.exist?(saved_file)).to be(true)
      expect(File.read(saved_file)).to include("allow :read_file")
    ensure
      FileUtils.rm_f(out_path) if defined?(out_path)
    end
  end

  describe "out/sample_policy.rb" do
    it "evaluates rules for read/write paths and .env / GEMINI.md protection" do
      sample_path = File.expand_path("../../out/sample_policy.rb", __dir__)
      expect(File.exist?(sample_path)).to be(true)

      policy = eval(File.read(sample_path)) # rubocop:disable Security/Eval
      expect(policy).to be_a(Antigravity::Policy)

      # Sensitive files: allow read, deny write
      expect(policy.evaluate(:read_file, { target_file: ".env" })[:status]).to eq(:allow)
      expect(policy.evaluate(:write_file, { target_file: ".env" })[:status]).to eq(:deny)

      expect(policy.evaluate(:read_file, { target_file: "GEMINI.md" })[:status]).to eq(:allow)
      expect(policy.evaluate(:write_file, { target_file: "GEMINI.md" })[:status]).to eq(:deny)

      # Read & write directories
      expect(policy.evaluate(:read_file, { path: "docs/USER_GUIDE.md" })[:status]).to eq(:allow)
      expect(policy.evaluate(:write_file, { path: "out/report.txt" })[:status]).to eq(:allow)
    end
  end
end
