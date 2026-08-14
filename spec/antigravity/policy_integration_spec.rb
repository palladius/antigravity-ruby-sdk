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
end
