# frozen_string_literal: true

require "spec_helper"

class WeatherTool < Antigravity::Tool
  name "get_weather", desc: "Retrieves weather for a city"
  param :city, type: :string, description: "Target city", required: true

  def call(city:)
    "Sunny in #{city}"
  end
end

class ZeroArityTool < Antigravity::Tool
  name "zero_arity", desc: "No args tool"

  def call
    "Zero args result"
  end
end

RSpec.describe Antigravity::Tool do
  it "auto-generates JSON schema for subclassed tools using concise name and desc" do
    schema = WeatherTool.to_json_schema

    expect(schema[:name]).to eq("get_weather")
    expect(schema[:description]).to eq("Retrieves weather for a city")
    expect(schema[:parameters][:properties][:city][:type]).to eq("string")
  end

  it "executes zero-arity tool call methods cleanly" do
    agent = Antigravity::Agent.new
    agent.register_tool(ZeroArityTool.new)

    result = agent.client.execute_tool(agent, "zero_arity", {})
    expect(result).to eq("Zero args result")
  end
end
