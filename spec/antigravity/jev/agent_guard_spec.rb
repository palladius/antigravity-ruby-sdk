# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'

# AgentGuard plugs the JEV guardrail into the core Antigravity::Agent hook
# pipeline, so the SDK agent and rujev share one safety brain.
RSpec.describe Antigravity::Jev::AgentGuard do
  let(:client) { Antigravity::Jev::Client.new(mock: true) }
  let(:guardrail) { Antigravity::Jev::Guardrail.new(client: client) }
  let(:hooks) { Antigravity::Hooks.new }

  def with_probability(prob)
    client.set_mock_handler { |_s, _q| { verdict: { type: 'noul', noul: prob } } }
  end

  it 'denies a shell tool call when JEV says it is unsafe' do
    with_probability(0.05)
    described_class.attach!(hooks, guardrail: guardrail)

    res = hooks.run_pre_tool('run_command', { 'CommandLine' => 'cat .env' })
    expect(res[:allowed]).to be false
    expect(res[:reason]).to include('JEV')
  end

  it 'allows a shell tool call when JEV says it is safe' do
    with_probability(0.97)
    described_class.attach!(hooks, guardrail: guardrail)

    expect(hooks.run_pre_tool('run_command', { 'CommandLine' => 'ls' })[:allowed]).to be true
  end

  it 'denies unsure commands unless yolo is enabled' do
    with_probability(0.6)
    described_class.attach!(hooks, guardrail: guardrail)
    expect(hooks.run_pre_tool('run_command', { command: 'cd ..' })[:allowed]).to be false

    yolo_hooks = Antigravity::Hooks.new
    described_class.attach!(yolo_hooks, guardrail: guardrail, yolo: true)
    expect(yolo_hooks.run_pre_tool('run_command', { command: 'cd ..' })[:allowed]).to be true
  end

  it 'does not call JEV for non-shell tools' do
    expect(guardrail).not_to receive(:evaluate)
    described_class.attach!(hooks, guardrail: guardrail)

    expect(hooks.run_pre_tool('view_file', { path: 'README.md' })[:allowed]).to be true
  end
end
