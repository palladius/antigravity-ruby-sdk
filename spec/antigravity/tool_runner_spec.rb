# frozen_string_literal: true

# Tests for the ToolRunner — registering tools, generating schemas,
# and executing tool callbacks. UNIT tests, no harness needed.

RSpec.describe Antigravity::ToolRunner do
  let(:runner) { described_class.new }

  describe '#register' do
    it 'registers a tool and stores it by name' do
      tool = build_test_tool(:get_weather, 'Gets weather') { |city:| "Sunny in #{city}" }
      runner.register(tool)
      expect(runner.registered?(:get_weather)).to be true
    end

    it 'raises on duplicate tool name' do
      tool = build_test_tool(:dupe, 'Dupe') { 'x' }
      runner.register(tool)
      expect { runner.register(tool) }.to raise_error(Antigravity::ToolError, /already registered/)
    end
  end

  describe '#execute' do
    it 'executes a registered tool with keyword args' do
      tool = build_test_tool(:greet, 'Greets') { |name:| "Hello #{name}!" }
      runner.register(tool)
      result = runner.execute(:greet, name: 'Riccardo')
      expect(result).to eq('Hello Riccardo!')
    end

    it 'returns error hash when tool raises' do
      tool = build_test_tool(:bomb, 'Explodes') { raise 'BOOM' }
      runner.register(tool)
      result = runner.execute(:bomb)
      expect(result).to be_a(Hash)
      expect(result[:error]).to include('BOOM')
    end

    it 'raises ToolNotFoundError for unknown tool' do
      expect {
        runner.execute(:nonexistent)
      }.to raise_error(Antigravity::ToolNotFoundError)
    end
  end

  describe '#to_harness_tools' do
    it 'generates an array of JSON-schema tool definitions' do
      tool = build_test_tool(:calculator, 'Does math',
        params: { expression: { type: :string, description: 'Math expression' } }
      ) { |expression:| eval(expression).to_s }

      runner.register(tool)
      schemas = runner.to_harness_tools

      expect(schemas).to be_an(Array)
      expect(schemas.length).to eq(1)
      expect(schemas.first[:name]).to eq('calculator')
      expect(schemas.first[:description]).to eq('Does math')
      expect(schemas.first[:parameters_json_schema]).to include('expression')
    end
  end

  # Helper to build a simple test tool
  def build_test_tool(name, description, params: {}, &block)
    Antigravity::Tool.define(name, desc: description, params: params, &block)
  end
end
