# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Safety do
  describe Antigravity::Safety::ProtectedFilesGuard do
    subject(:guard) { described_class.new }

    it "blocks attempts to edit .env or Gemfile" do
      result_env = guard.call("write_file", { path: ".env" })
      expect(result_env[:status]).to eq(:deny)
      expect(result_env[:reason]).to include("Security Policy Violation")

      result_gemfile = guard.call("write_file", { path: "Gemfile" })
      expect(result_gemfile[:status]).to eq(:deny)
    end

    it "allows editing safe files" do
      result_safe = guard.call("write_file", { path: "app/models/user.rb" })
      expect(result_safe).to eq(:allow)
    end
  end

  describe Antigravity::Safety::SecretMasker do
    subject(:masker) { described_class.new }

    it "redacts Google API keys and bearer tokens from tool results" do
      raw_output = "API_KEY=AIzaSyA12345678901234567890123456789012"
      sanitized = masker.call("get_keys", {}, raw_output)

      expect(sanitized).not_to include("AIzaSy")
      expect(sanitized).to include("[REDACTED_SECRET]")
    end
  end
end
