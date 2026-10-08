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
  let(:gemini) { instance_double(Antigravity::Jev::Gemini) }
  let(:harness) do
    described_class.new(client: client, router: router, guardrail: guardrail, output: output, input: input,
                        gemini: gemini)
  end

  def reply(answer:, command: nil, thinking: nil, warnings: [])
    Antigravity::Jev::Gemini::Reply.new(thinking: thinking, answer: answer, command: command,
                                        model: 'gemini-3.8-flash', warnings: warnings)
  end

  def jev_says(safe_probability)
    client.set_mock_handler do |_state, questions|
      if questions.key?(:category)
        { category: { type: 'choice', choice: 'simple', confidence: 0.95 } }
      else
        { verdict: { type: 'noul', noul: safe_probability } }
      end
    end
  end

  describe '#process' do
    it 'runs the approved command, then feeds its output back to the model for the final answer' do
      jev_says(0.98)
      allow(gemini).to receive(:ask).and_return(
        reply(answer: "```bash\nls\n```", command: 'ls'),
        reply(answer: 'Ci sono due file.')
      )
      allow(harness).to receive(:run_system_command).with('ls').and_return("file1.txt\nfile2.txt")

      result = harness.process('Show me the list of this folder')

      expect(result[:executed]).to be true
      expect(result[:status]).to eq(:answered)
      expect(output.string).to include("ROUTED: #{Antigravity::Jev.fast_model}")
      expect(output.string).to include('APPROVED: ls')
      expect(output.string).to include('🤖 Ci sono due file.')
      expect(gemini).to have_received(:ask).with(a_string_including('file1.txt'), any_args)
    end

    it 'BLOCKS a destructive command and never runs it' do
      jev_says(0.05)
      allow(gemini).to receive(:ask).and_return(reply(answer: "```bash\nrm README.md\n```", command: 'rm README.md'))
      expect(harness).not_to receive(:run_system_command)

      result = harness.process('Delete the README.md in this folder')

      expect(result[:executed]).to be false
      expect(result[:status]).to eq(:blocked)
      expect(output.string).to include('BLOCKED: rm README.md')
    end

    it 'asks confirmation on the second line for unsure commands' do
      jev_says(0.55)
      input.string = "y\n"
      allow(gemini).to receive(:ask).and_return(reply(answer: '', command: 'cd ..'), reply(answer: 'Fatto.'))
      allow(harness).to receive(:run_system_command).with('cd ..').and_return('')

      result = harness.process('Move out of this folder')

      expect(result[:executed]).to be true
      expect(output.string).to include("UNSURE: cd ..\n")
      expect(output.string).to include('Execute this command? [y/N]: ')
    end

    it 'auto-executes unsure commands without prompting when yolo: true' do
      jev_says(0.55)
      allow(gemini).to receive(:ask).and_return(reply(answer: '', command: 'cd ..'), reply(answer: 'Fatto.'))
      allow(harness).to receive(:run_system_command).with('cd ..').and_return('')

      result = harness.process('Move out of this folder', yolo: true)

      expect(result[:executed]).to be true
      expect(output.string).not_to include('Execute this command? [y/N]: ')
    end

    it 'renders thinking (🤔) and answer (🤖) and skips the guardrail when there is no command' do
      jev_says(0.9)
      allow(gemini).to receive(:ask).and_return(reply(thinking: 'Analizzo il repo', answer: 'È un SDK Ruby'))
      expect(guardrail).not_to receive(:execute_guarded)

      result = harness.process("Cosa c'è in questo repo?")

      expect(output.string).to include('🤔 Analizzo il repo')
      expect(output.string).to include('🤖 È un SDK Ruby')
      expect(output.string).not_to include('Interpreted:')
      expect(result[:status]).to eq(:answered)
    end

    it 'shows Gemini errors instead of silently faking a command' do
      jev_says(0.9)
      allow(gemini).to receive(:ask).and_raise(Antigravity::Jev::ApiError, 'Gemini HTTP 404: not found')
      expect(guardrail).not_to receive(:execute_guarded)

      result = harness.process('Trova vulnerabilita')

      expect(output.string).to include('⚠️')
      expect(output.string).to include('404')
      expect(result[:status]).to eq(:error)
    end

    it 'surfaces fallback warnings (e.g. 503 on the routed model)' do
      jev_says(0.9)
      allow(gemini).to receive(:ask).and_return(reply(answer: 'ok', warnings: ['Gemini HTTP 503 on gemini-3.8-flash']))

      harness.process('ciao')

      expect(output.string).to include('503')
    end

    it 'bypasses the model for direct shell commands but still guards them' do
      jev_says(0.97)
      expect(gemini).not_to receive(:ask)
      allow(harness).to receive(:run_system_command).with('git status').and_return('clean')

      expect(harness.process('git status')[:executed]).to be true
    end

    it 'skips the follow-up model call when the command is marked ```bash final' do
      jev_says(0.98)
      final = reply(answer: "```bash final\nls\n```", command: 'ls')
      final.final = true
      allow(gemini).to receive(:ask).and_return(final)
      allow(harness).to receive(:run_system_command).with('ls').and_return("a\nb")

      result = harness.process('Show me the list of this folder')

      expect(gemini).to have_received(:ask).once
      expect(result[:executed]).to be true
      expect(result[:status]).to eq(:answered)
    end

    it 'with model: forced, skips JEV routing and uses that model' do
      jev_says(0.9)
      expect(router).not_to receive(:route)
      allow(gemini).to receive(:ask).and_return(reply(answer: 'ok'))

      result = harness.process('ciao', model: 'gemini-3.6-flash')

      expect(gemini).to have_received(:ask).with('ciao', hash_including(model: 'gemini-3.6-flash'))
      expect(result[:route].model).to eq('gemini-3.6-flash')
      expect(output.string).to include('gemini-3.6-flash')
    end

    it 'prints streamed deltas live and does not re-print the final reply' do
      jev_says(0.9)
      allow(gemini).to receive(:ask) do |*_args, &blk|
        blk.call(:thought, "Analizzo\n")
        blk.call(:text, "Streaming!\n")
        reply(thinking: 'Analizzo', answer: 'Streaming!')
      end

      harness.process('ciao')

      expect(output.string.scan('🤖 Streaming!').size).to eq(1)
      expect(output.string).to include('🤔 Analizzo')
    end
  end

  it 'uses the offline Gemini stand-in when the JEV client is in mock mode' do
    h = described_class.new(client: client, router: router, guardrail: guardrail, output: output, input: input)
    expect(h.gemini).to be_a(Antigravity::Jev::Gemini::Offline)
  end

  describe 'network errors 🔌' do
    it 'prints a red 🔌 line and executes nothing when JEV is unreachable (fails closed)' do
      allow(router).to receive(:route).and_raise(Antigravity::Jev::NetworkError, 'JEV (System One) unreachable: Net::ReadTimeout')
      expect(harness).not_to receive(:run_system_command)

      res = harness.process('rm -rf /tmp/x')

      expect(res[:status]).to eq(:network_error)
      expect(output.string).to include('🔌')
      expect(output.string).to include('Net::ReadTimeout')
    end
  end
end
