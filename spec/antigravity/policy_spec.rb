# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Antigravity::Policy do
  describe '.define' do
    it 'creates a policy with the given block' do
      policy = described_class.define do
        allow_all
      end
      expect(policy).to be_a(described_class)
    end
  end

  describe 'precedence' do
    it 'respects Specific Deny > Specific Allow > Wildcard Deny' do
      policy = described_class.define do
        deny_all
        allow :run_command
        deny :run_command, when: ->(**args) { args[:args][:command_line] == 'rm -rf /' }
      end

      # Wildcard deny
      expect(policy.evaluate(:list_dir, {})[:status]).to eq(:deny)

      # Specific allow
      expect(policy.evaluate(:run_command, { command_line: 'ls' })[:status]).to eq(:allow)

      # Specific deny
      expect(policy.evaluate(:run_command, { command_line: 'rm -rf /' })[:status]).to eq(:deny)
    end

    it 'respects Confirm' do
      policy = described_class.define do
        allow_all
        confirm :create_file
      end

      expect(policy.evaluate(:list_dir, {})[:status]).to eq(:allow)
      
      # confirm default (no handler) is deny (fail-closed)
      eval_res = policy.evaluate(:create_file, {})
      expect(eval_res[:status]).to eq(:deny)
    end

    it 'calls global confirm handler' do
      policy = described_class.define do
        allow_all
        confirm :create_file
      end

      handler_called = false
      policy.on_confirm do |ctx|
        handler_called = true
        ctx[:name] == :create_file
      end

      # Evaluating confirm will execute the handler, if it returns true -> allow
      eval_res = policy.evaluate(:create_file, {})
      expect(handler_called).to be true
      expect(eval_res[:status]).to eq(:allow)
    end

    it 'defaults to deny if no confirm handler is set' do
      policy = described_class.define do
        allow_all
        confirm :create_file
      end

      eval_res = policy.evaluate(:create_file, {})
      expect(eval_res[:status]).to eq(:deny)
    end

    it 'supports local confirm handler' do
      policy = described_class.define do
        allow_all
        confirm(:create_file) { |ctx| ctx[:args][:target_file] == 'ok.txt' }
      end

      expect(policy.evaluate(:create_file, { target_file: 'ok.txt' })[:status]).to eq(:allow)
      expect(policy.evaluate(:create_file, { target_file: 'bad.txt' })[:status]).to eq(:deny)
    end

    it 'handles specific confirm with when' do
      policy = described_class.define do
        allow_all
        confirm :create_file, when: ->(**args) { args[:args][:target_file].include?('.key') }
      end

      expect(policy.evaluate(:create_file, { target_file: 'test.txt' })[:status]).to eq(:allow)
      
      eval_res = policy.evaluate(:create_file, { target_file: 'secret.key' })
      expect(eval_res[:status]).to eq(:deny) # default confirm behavior is deny
    end
  end

  describe '.allow_all and .deny_all' do
    it 'provides allow_all one-liner' do
      policy = described_class.allow_all
      expect(policy.evaluate(:anything, {})[:status]).to eq(:allow)
    end

    it 'provides deny_all one-liner' do
      policy = described_class.deny_all
      expect(policy.evaluate(:anything, {})[:status]).to eq(:deny)
    end
  end
end
