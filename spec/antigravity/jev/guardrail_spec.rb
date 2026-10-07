# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'
require 'antigravity/jev/guardrail'

RSpec.describe Antigravity::Jev::Guardrail do
  let(:client) { Antigravity::Jev::Client.new(mock: true) }
  let(:guardrail) { described_class.new(client: client) }

  describe '#evaluate' do
    it 'evaluates safe command with high probability as :allow' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.992 } }
      end

      result = guardrail.evaluate('ls -la')
      expect(result.verdict).to eq(:allow)
      expect(result.allowed?).to be true
      expect(result.probability).to eq(0.992)
    end

    it 'evaluates dangerous command with low probability as :deny' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.011 } }
      end

      result = guardrail.evaluate('rm -rf /')
      expect(result.verdict).to eq(:deny)
      expect(result.denied?).to be true
      expect(result.probability).to eq(0.011)
    end

    it 'evaluates ambiguous command with middle probability as :ask' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.524 } }
      end

      result = guardrail.evaluate('cat .env')
      expect(result.verdict).to eq(:ask)
      expect(result.ask?).to be true
      expect(result.probability).to eq(0.524)
    end
  end

  describe '#execute_guarded (safe execution verification)' do
    let(:output) { StringIO.new }

    it 'auto-executes allowed command without asking' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.95 } }
      end

      executed = false
      res = guardrail.execute_guarded(
        "echo 'hello safe world'",
        output_stream: output
      ) do |cmd|
        executed = true
        "executed: #{cmd}"
      end

      expect(executed).to be true
      expect(res[:executed]).to be true
      expect(output.string).to include("APPROVED: echo 'hello safe world'")
      expect(output.string).not_to include('Execute this command?')
    end

    it 'blocks denied command without executing' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.05 } }
      end

      executed = false
      res = guardrail.execute_guarded(
        'rm -rf /some/safe/dummy/path',
        output_stream: output
      ) do |_cmd|
        executed = true
      end

      expect(executed).to be false
      expect(res[:executed]).to be false
      expect(res[:status]).to eq(:blocked)
      expect(output.string).to include('BLOCKED: rm -rf /some/safe/dummy/path')
    end

    it "prompts user on second line and executes if user enters 'y'" do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.55 } }
      end

      input = StringIO.new("y\n")
      executed = false

      res = guardrail.execute_guarded(
        'cat .env',
        input_stream: input,
        output_stream: output
      ) do |_cmd|
        executed = true
        'mock content'
      end

      expect(executed).to be true
      expect(res[:executed]).to be true
      expect(output.string).to include("UNSURE: cat .env\n")
      expect(output.string).to include('Execute this command? [y/N]: ')
    end

    it "prompts user on second line and does NOT execute if user enters 'n'" do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.55 } }
      end

      input = StringIO.new("n\n")
      executed = false

      res = guardrail.execute_guarded(
        'cat .env',
        input_stream: input,
        output_stream: output
      ) do |_cmd|
        executed = true
      end

      expect(executed).to be false
      expect(res[:executed]).to be false
      expect(res[:status]).to eq(:rejected_by_user)
      expect(output.string).to include("UNSURE: cat .env\n")
      expect(output.string).to include('Execute this command? [y/N]: ')
    end

    it 'auto-executes unsure command without asking when yolo: true' do
      client.set_mock_handler do |_state, _questions|
        { verdict: { type: 'noul', noul: 0.55 } }
      end

      executed = false
      res = guardrail.execute_guarded(
        'cat .env',
        yolo: true,
        output_stream: output
      ) do |_cmd|
        executed = true
        'mock content'
      end

      expect(executed).to be true
      expect(res[:executed]).to be true
      expect(output.string).not_to include('Execute this command? [y/N]: ')
    end

    it 'raises GuardrailBlockedError if catastrophic wipe is ever attempted' do
      expect do
        guardrail.send(:run_command, 'rm -rf /')
      end.to raise_error(Antigravity::Jev::GuardrailBlockedError,
                         /Execution of catastrophic command is strictly prohibited/)
    end
  end
end
