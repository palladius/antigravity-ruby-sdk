# frozen_string_literal: true

require "spec_helper"

RSpec.describe Antigravity::Hooks do
  subject(:agent) { Antigravity::Agent.new }

  it "executes pre-prompt and post-response hooks" do
    pre_called = false
    post_called = false

    agent.before_prompt do |prompt_text|
      pre_called = true if prompt_text == "Test prompt"
    end

    agent.after_response do |response|
      post_called = true if response.is_a?(Antigravity::Message)
    end

    agent.prompt("Test prompt")

    expect(pre_called).to be true
    expect(post_called).to be true
  end
end
