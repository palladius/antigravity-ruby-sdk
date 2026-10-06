# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'
require 'antigravity/jev/harness'

RSpec.describe Antigravity::Jev::Harness do
  let(:client) { Antigravity::Jev::Client.new(mock: true) }
  let(:guardrail) { Antigravity::Jev::Guardrail.new(client: client) }
  let(:router) { Antigravity::Jev::Router.new(client: client) }
  let(:output) { StringIO.new }
  let(:input) { StringIO.new }
  let(:harness) do
    described_class.new(client: client, router: router, guardrail: guardrail, output: output, input: input)
  end

  describe '#run_prompt' do
    it "converts 'Show me the list of this folder' to ls and executes when approved" do
      client.set_mock_handler do |_state, questions|
        if questions.key?(:category)
          { category: { type: 'choice', choice: 'simple', confidence: 0.95 } }
        else
          { verdict: { type: 'noul', noul: 0.98 } }
        end
      end

      allow(harness).to receive(:translate_to_command).with('Show me the list of this folder',
                                                            anything).and_return('ls')
      allow(harness).to receive(:run_system_command).with('ls').and_return("file1.txt\nfile2.txt")

      result = harness.process('Show me the list of this folder')

      expect(result[:executed]).to be true
      expect(result[:command]).to eq('ls')
      expect(output.string).to include('ROUTED: gemini-3.8-flash-low')
      expect(output.string).to include('APPROVED: ls')
    end

    it "converts 'Delete the README.md in this folder' to rm README.md and BLOCKS it" do
      client.set_mock_handler do |_state, questions|
        if questions.key?(:category)
          { category: { type: 'choice', choice: 'simple', confidence: 0.90 } }
        else
          { verdict: { type: 'noul', noul: 0.05 } }
        end
      end

      allow(harness).to receive(:translate_to_command).with('Delete the README.md in this folder',
                                                            anything).and_return('rm README.md')

      result = harness.process('Delete the README.md in this folder')

      expect(result[:executed]).to be false
      expect(result[:status]).to eq(:blocked)
      expect(output.string).to include('BLOCKED: rm README.md')
    end

    it "converts 'Move out of this folder' to cd .. and asks user confirmation on second line" do
      client.set_mock_handler do |_state, questions|
        if questions.key?(:category)
          { category: { type: 'choice', choice: 'simple', confidence: 0.90 } }
        else
          { verdict: { type: 'noul', noul: 0.55 } }
        end
      end

      input.string = "y\n"
      allow(harness).to receive(:translate_to_command).with('Move out of this folder', anything).and_return('cd ..')
      allow(harness).to receive(:run_system_command).with('cd ..').and_return('')

      result = harness.process('Move out of this folder')

      expect(result[:executed]).to be true
      expect(output.string).to include("UNSURE: cd ..\n")
      expect(output.string).to include('Execute this command? [y/N]: ')
    end
  end
end
