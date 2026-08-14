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
  describe 'predicate helpers' do
    describe '#cmd' do
      it 'matches substring in command_line or CommandLine' do
        policy = described_class.define do
          allow_all
          deny :run_command, when: cmd('rm -rf', :sudo)
        end

        expect(policy.evaluate(:run_command, { command_line: 'ls -l' })[:status]).to eq(:allow)
        expect(policy.evaluate(:run_command, { command_line: 'sudo rm -rf /' })[:status]).to eq(:deny)
        expect(policy.evaluate(:run_command, { 'CommandLine' => 'sudo ls' })[:status]).to eq(:deny)
      end
    end

    describe '#path' do
      it 'glob-matches path-like arguments' do
        policy = described_class.define do
          allow_all
          deny :read_file, when: path('*.key', '.env*')
        end

        expect(policy.evaluate(:read_file, { path: 'test.txt' })[:status]).to eq(:allow)
        expect(policy.evaluate(:read_file, { target: 'secret.key' })[:status]).to eq(:deny)
        expect(policy.evaluate(:read_file, { file_path: '.env.local' })[:status]).to eq(:deny)
      end
    end

    describe '#args_match' do
      it 'regex-matches named arguments' do
        policy = described_class.define do
          allow_all
          deny :create_file, when: args_match(content: /password/i)
        end

        expect(policy.evaluate(:create_file, { content: 'hello world' })[:status]).to eq(:allow)
        expect(policy.evaluate(:create_file, { content: 'my Password is 123' })[:status]).to eq(:deny)
      end
    end
  end

  # ------------------------------------------------------------------
  # Preset policies
  # ------------------------------------------------------------------

  describe '.preset' do
    it 'resolves :cautious' do
      expect(described_class.preset(:cautious)).to be_a(described_class)
    end

    it 'resolves :default' do
      expect(described_class.preset(:default)).to be_a(described_class)
    end

    it 'resolves :turbo' do
      expect(described_class.preset(:turbo)).to be_a(described_class)
    end

    it 'raises on unknown preset' do
      expect { described_class.preset(:yolo) }.to raise_error(ArgumentError, /Unknown preset :yolo/)
    end
  end

  describe '.cautious' do
    subject(:policy) { described_class.cautious }

    it 'allows read-only tools' do
      Antigravity::Policy::READONLY_TOOLS.each do |tool|
        expect(policy.evaluate(tool, {})[:status]).to eq(:allow), "Expected #{tool} to be allowed"
      end
    end

    it 'allows safe shell commands' do
      expect(policy.evaluate(:run_command, { command_line: 'echo hello' })[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: 'git status' })[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: 'ls -la' })[:status]).to eq(:allow)
    end

    it 'hard-denies catastrophic commands' do
      expect(policy.evaluate(:run_command, { command_line: 'rm -rf /' })[:status]).to eq(:deny)
      expect(policy.evaluate(:run_command, { command_line: 'mkfs /dev/sda1' })[:status]).to eq(:deny)
    end

    it 'hard-denies risky commands' do
      expect(policy.evaluate(:run_command, { command_line: 'rm important.txt' })[:status]).to eq(:deny)
      expect(policy.evaluate(:run_command, { command_line: 'killall node' })[:status]).to eq(:deny)
    end

    it 'confirms write tools (default deny without handler)' do
      Antigravity::Policy::WRITE_TOOLS.each do |tool|
        expect(policy.evaluate(tool, {})[:status]).to eq(:deny), "Expected #{tool} to need confirmation (deny w/o handler)"
      end
    end

    it 'denies unknown tools' do
      expect(policy.evaluate(:unknown_tool, {})[:status]).to eq(:deny)
    end
  end

  describe '.default' do
    subject(:policy) { described_class.default }

    it 'allows read-only tools' do
      Antigravity::Policy::READONLY_TOOLS.each do |tool|
        expect(policy.evaluate(tool, {})[:status]).to eq(:allow), "Expected #{tool} to be allowed"
      end
    end

    it 'allows normal shell commands' do
      expect(policy.evaluate(:run_command, { command_line: 'bundle install' })[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: 'ruby -v' })[:status]).to eq(:allow)
    end

    it 'allows write tools for normal files' do
      expect(policy.evaluate(:write_to_file, { path: 'app.rb' })[:status]).to eq(:allow)
      expect(policy.evaluate(:file_edit, { path: 'README.md' })[:status]).to eq(:allow)
    end

    it 'confirms writes to sensitive files (deny w/o handler)' do
      expect(policy.evaluate(:write_to_file, { path: '.env' })[:status]).to eq(:deny)
      expect(policy.evaluate(:file_edit, { path: 'server.key' })[:status]).to eq(:deny)
      expect(policy.evaluate(:write_to_file, { path: '.env.production' })[:status]).to eq(:deny)
    end

    it 'hard-denies catastrophic commands' do
      expect(policy.evaluate(:run_command, { command_line: 'rm -rf /' })[:status]).to eq(:deny)
    end

    it 'confirms risky commands (deny w/o handler)' do
      expect(policy.evaluate(:run_command, { command_line: 'rm old_file.txt' })[:status]).to eq(:deny)
      expect(policy.evaluate(:run_command, { command_line: 'killall nginx' })[:status]).to eq(:deny)
    end
  end

  describe '.turbo' do
    subject(:policy) { described_class.turbo }

    it 'allows everything by default' do
      expect(policy.evaluate(:list_dir, {})[:status]).to eq(:allow)
      expect(policy.evaluate(:run_command, { command_line: 'npm install' })[:status]).to eq(:allow)
      expect(policy.evaluate(:write_to_file, { path: 'app.rb' })[:status]).to eq(:allow)
      expect(policy.evaluate(:unknown_custom_tool, {})[:status]).to eq(:allow)
    end

    it 'hard-denies catastrophic commands' do
      expect(policy.evaluate(:run_command, { command_line: 'rm -rf /' })[:status]).to eq(:deny)
      expect(policy.evaluate(:run_command, { command_line: 'mkfs /dev/sda' })[:status]).to eq(:deny)
    end

    it 'confirms writes to sensitive files (deny w/o handler)' do
      expect(policy.evaluate(:write_to_file, { path: '.env' })[:status]).to eq(:deny)
      expect(policy.evaluate(:file_edit, { path: 'id_rsa_key' })[:status]).to eq(:deny)
    end

    it 'allows risky commands (turbo trusts the user)' do
      expect(policy.evaluate(:run_command, { command_line: 'rm old_file.txt' })[:status]).to eq(:allow)
    end
  end
end
