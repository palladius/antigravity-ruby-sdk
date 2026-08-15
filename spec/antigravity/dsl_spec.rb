# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Top-Level DSL Sugar" do
  describe "Antigravity.tool" do
    it "defines a dynamic tool via top-level Antigravity.tool" do
      t = Antigravity.tool(:ping, desc: "Pings host") { |host:| "pong #{host}" }
      expect(t.tool_name).to eq("ping")
      expect(t.call(host: "localhost")).to eq("pong localhost")
    end
  end

  describe "Antigravity.policy" do
    it "defines a policy via top-level Antigravity.policy" do
      pol = Antigravity.policy do
        allow :read_file
        deny :delete_file
      end
      expect(pol).to be_a(Antigravity::Policy)
      expect(pol.evaluate(:read_file, {})[:status]).to eq(:allow)
      expect(pol.evaluate(:delete_file, {})[:status]).to eq(:deny)
    end
  end
end
