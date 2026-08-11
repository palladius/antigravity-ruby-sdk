# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Custom Safety Hooks" do
  class CustomGuard
    def call(_tool_name, params)
      if params[:path] == ".env"
        { status: :deny, reason: "Forbidden file" }
      else
        :allow
      end
    end

    def to_proc
      method(:call).to_proc
    end
  end

  class CustomMasker
    def call(_tool_name, _params, result)
      result.to_s.gsub(/SECRET_KEY/, "[REDACTED]")
    end

    def to_proc
      method(:call).to_proc
    end
  end

  subject(:agent) do
    Antigravity::Agent.new do |a|
      a.before_tool_call(&CustomGuard.new)
      a.after_tool_call(&CustomMasker.new)
      a.register_tool("write_file", description: "Edits file") { |params| "Edited #{params[:path]}" }
      a.register_tool("get_key", description: "Gets key") { |_params| "Key: SECRET_KEY" }
    end
  end

  it "blocks tool calls when custom pre-hook returns deny" do
    output = agent.client.execute_tool(agent, "write_file", { path: ".env" })
    expect(output).to include("TOOL BLOCKED: Forbidden file")
  end

  it "sanitizes tool outputs when custom post-hook transforms result" do
    output = agent.client.execute_tool(agent, "get_key", {})
    expect(output).to eq("Key: [REDACTED]")
  end
end
