# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Telegram Bot Script' do
  let(:script_path) { File.expand_path('../../examples/08_skill_telegram_bot.rb', __dir__) }

  describe 'syntax validation' do
    it 'has valid Ruby syntax (no unicode surrogate pair errors)' do
      result = `ruby -c #{script_path} 2>&1`
      expect(result.strip).to eq('Syntax OK'), "Syntax check failed: #{result}"
    end

    it 'does not contain literal \\uDxxx surrogate escape sequences' do
      script = File.read(script_path, encoding: 'UTF-8')
      # Match literal backslash-u-Dxxx patterns (surrogate pairs invalid in Ruby)
      surrogates = script.scan(/\\uD[89A-Fa-f][0-9A-Fa-f]{2}/)
      expect(surrogates).to be_empty,
        "Found invalid unicode surrogate escape sequences: #{surrogates.uniq.join(', ')}"
    end
  end

  describe 'Tool.define' do
    it 'creates a dynamic tool with name and description' do
      tool = Antigravity::Tool.define(:test_tool,
        desc: 'A test tool',
        params: { name: { type: :string, desc: 'A name' } }
      ) { |name:| "Hello #{name}" }

      expect(tool.tool_name).to eq('test_tool')
      schema = tool.to_json_schema
      expect(schema[:name]).to eq('test_tool')
      expect(schema[:description]).to eq('A test tool')
      expect(schema[:parameters][:properties]).to have_key(:name)
    end

    it 'executes the tool block with keyword arguments' do
      tool = Antigravity::Tool.define(:greeter,
        desc: 'Greet',
        params: { who: { type: :string } }
      ) { |who:| "Ciao #{who}!" }

      expect(tool.call(who: 'Riccardo')).to eq('Ciao Riccardo!')
    end
  end

  describe 'tilde expansion' do
    it 'File.expand_path expands ~ to home directory' do
      expanded = File.expand_path('~/git/some-skill')
      expect(expanded).to start_with('/')
      expect(expanded).not_to include('~')
      expect(expanded).to include('/git/some-skill')
    end

    it 'does not expand URLs' do
      url = 'https://github.com/example/skill'
      result = url.start_with?('http') ? url : File.expand_path(url)
      expect(result).to eq(url)
    end
  end
end
