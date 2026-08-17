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
    it "exports policy rules to valid Ruby DSL syntax string with DRY array grouping" do
      pol = Antigravity::Policy.define do
        allow :run_command, when: cmd(["gcloud", "kubectl"])
        allow :read_file
      end

      dsl_code = pol.to_ruby_dsl
      expect(dsl_code).to include("Antigravity.policy do")
      expect(dsl_code).to include("allow :run_command, when: cmd([")
      expect(dsl_code).to include("'gcloud'")
      expect(dsl_code).to include("'kubectl'")
      expect(dsl_code).to include("allow :read_file")
    end
  end
end
