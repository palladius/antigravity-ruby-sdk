# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Antigravity::Agent, 'Policy Integration' do
  it 'enforces policies on tools' do
    policy = Antigravity::Policy.define do
      deny_all
      allow :allowed_tool
      deny :allowed_tool, when: ->(**args) { args[:args][:bad] }
    end

    agent = described_class.new(policies: [policy])
    
    # Test hooks manually since agent tool execution goes through hooks.run_pre_tool
    expect(agent.hooks.run_pre_tool(:allowed_tool, { bad: false })[:allowed]).to be true
    expect(agent.hooks.run_pre_tool(:allowed_tool, { bad: true })[:allowed]).to be false
    expect(agent.hooks.run_pre_tool(:disallowed_tool, {})[:allowed]).to be false
  end

  it 'accepts policy: symbol shorthand for presets' do
    agent = described_class.new(policy: :turbo, auto_logger: false)

    # Turbo allows everything...
    expect(agent.hooks.run_pre_tool(:list_dir, {})[:allowed]).to be true
    expect(agent.hooks.run_pre_tool(:run_command, { command_line: 'npm install' })[:allowed]).to be true

    # ...except catastrophic commands
    expect(agent.hooks.run_pre_tool(:run_command, { command_line: 'rm -rf /' })[:allowed]).to be false
  end

  it 'accepts policy: Policy object directly' do
    custom = Antigravity::Policy.define do
      deny_all
      allow :view_file
    end
    agent = described_class.new(policy: custom, auto_logger: false)

    expect(agent.hooks.run_pre_tool(:view_file, {})[:allowed]).to be true
    expect(agent.hooks.run_pre_tool(:run_command, {})[:allowed]).to be false
  end
end
