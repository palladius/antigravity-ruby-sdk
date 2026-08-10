# frozen_string_literal: true

require "spec_helper"

class WeatherTool
  include Antigravity::Tool
  tool_name "get_weather"
  tool_description "Retrieves weather for a city"
  param :city, type: :string, description: "Target city", required: true

  def call(city:)
    "Sunny in #{city}"
  end
end

RSpec.describe Antigravity::Tool do
  it "auto-generates JSON schema for declarative tools" do
    schema = WeatherTool.to_json_schema

    expect(schema[:name]).to eq("get_weather")
    expect(schema[:description]).to eq("Retrieves weather for a city")
    expect(schema[:parameters][:properties][:city][:type]).to eq("string")
  end
end
