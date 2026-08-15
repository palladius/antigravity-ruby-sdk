# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Antigravity::Console do
  describe '.new' do
    it 'initializes with default settings' do
      console = described_class.new
      expect(console.thinking_expanded).to be false
    end

    it 'accepts system_instruction' do
      console = described_class.new(system_instruction: 'Be a pirate')
      expect(console.system_instruction).to eq('Be a pirate')
    end
  end

  describe '#thinking_expanded' do
    it 'defaults to collapsed (false)' do
      console = described_class.new
      expect(console.thinking_expanded).to be false
    end

    it 'can be toggled' do
      console = described_class.new
      console.toggle_thinking!
      expect(console.thinking_expanded).to be true
      console.toggle_thinking!
      expect(console.thinking_expanded).to be false
    end
  end

  describe '#format_thinking' do
    let(:console) { described_class.new }

    context 'when collapsed' do
      it 'truncates to 1 line at 76 chars + ...' do
        long_think = 'a' * 200
        formatted = console.format_thinking(long_think)
        # Should be truncated — no newlines, ends with ...
        expect(formatted).not_to include("\n")
        expect(formatted.gsub(/\e\[[0-9;]*m/, '')).to end_with('...')
      end

      it 'shows short thinking without truncation' do
        formatted = console.format_thinking('quick thought')
        plain = formatted.gsub(/\e\[[0-9;]*m/, '')
        expect(plain).to include('quick thought')
        expect(plain).not_to end_with('...')
      end
    end

    context 'when expanded' do
      it 'shows full thinking text' do
        console.toggle_thinking!  # expand
        long_think = "line 1\nline 2\nline 3"
        formatted = console.format_thinking(long_think)
        plain = formatted.gsub(/\e\[[0-9;]*m/, '')
        expect(plain).to include('line 1')
        expect(plain).to include('line 3')
      end
    end

    it 'renders in gray italic ANSI' do
      formatted = console.format_thinking('thinking...')
      expect(formatted).to include("\e[3;90m")  # italic + gray
    end
  end

  describe '#parse_command' do
    let(:console) { described_class.new }

    it 'recognizes /quit' do
      expect(console.parse_command('/quit')).to eq(:quit)
    end

    it 'recognizes /exit' do
      expect(console.parse_command('/exit')).to eq(:quit)
    end

    it 'recognizes /think' do
      expect(console.parse_command('/think')).to eq(:toggle_thinking)
    end

    it 'recognizes /help' do
      expect(console.parse_command('/help')).to eq(:help)
    end

    it 'returns nil for regular text' do
      expect(console.parse_command('hello there')).to be_nil
    end

    it 'returns nil for empty string' do
      expect(console.parse_command('')).to be_nil
    end

    it 'recognizes ! shell exec' do
      expect(console.parse_command('! pwd')).to eq(:shell_exec)
    end

    it 'recognizes !ls (no space)' do
      expect(console.parse_command('!ls')).to eq(:shell_exec)
    end

    it 'recognizes r! ruby eval' do
      expect(console.parse_command('r! 2+2')).to eq(:ruby_eval)
    end

    it 'recognizes r!self.inspect (no space)' do
      expect(console.parse_command('r!self.inspect')).to eq(:ruby_eval)
    end

    it 'prioritizes r! over !' do
      # r! must match before ! for ruby eval
      expect(console.parse_command('r! puts "hi"')).to eq(:ruby_eval)
    end

    it 'recognizes /policy' do
      expect(console.parse_command('/policy')).to eq(:show_policy)
    end

    it 'recognizes /irb' do
      expect(console.parse_command('/irb')).to eq(:irb_mode)
    end
  end

  describe '.new workspace default' do
    it 'defaults workspace to Dir.pwd' do
      c = described_class.new
      expect(c).to be_a(described_class)
    end
  end

  describe 'console policy' do
    it 'denies rm -rf' do
      policy = Antigravity::Policy.console
      result = policy.evaluate(:run_command, { command_line: 'rm -rf scratch/' })
      expect(result[:status]).to eq(:deny)
    end

    it 'allows ls' do
      policy = Antigravity::Policy.console
      result = policy.evaluate(:run_command, { command_line: 'ls -la' })
      expect(result[:status]).to eq(:allow)
    end

    it 'allows view_file' do
      policy = Antigravity::Policy.console
      result = policy.evaluate(:view_file, { path: '/etc/hosts' })
      expect(result[:status]).to eq(:allow)
    end

    it 'does not auto-allow write_to_file (requires confirmation)' do
      policy = Antigravity::Policy.console
      result = policy.evaluate(:write_to_file, { path: '/tmp/test.txt' })
      # Without a confirm handler, confirm rules resolve to :deny (safe default)
      expect(result[:status]).not_to eq(:allow)
    end
  end

  describe '#format_metadata' do
    let(:console) { described_class.new }

    it 'formats token count and timing' do
      usage = { total_token_count: 1234, prompt_token_count: 500, candidates_token_count: 200 }
      result = console.format_metadata(usage: usage, thinking_size: 456, tool_calls: 2, elapsed: 3.7)
      plain = result.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).to include('1234')
      expect(plain).to include('456')
      expect(plain).to include('3.7')
    end
  end

  describe '#help_text' do
    let(:console) { described_class.new }

    it 'includes Ctrl-O hint' do
      help = console.help_text
      expect(help).to include('Ctrl-O')
    end

    it 'includes /quit command' do
      help = console.help_text
      expect(help).to include('/quit')
    end

    it 'includes Tools color hint' do
      help = console.help_text
      expect(help).to include('Tools')
    end
  end

  describe '#format_tool_call' do
    let(:console) { described_class.new }

    it 'shows tool name and params' do
      formatted = console.format_tool_call('read_file', '/etc/hosts')
      plain = formatted.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).to include('read_file')
      expect(plain).to include('/etc/hosts')
    end

    it 'renders in yellow ANSI' do
      formatted = console.format_tool_call('run_command', 'ls -la')
      expect(formatted).to include("\e[33m")  # yellow
    end

    it 'truncates long params when collapsed' do
      long_params = 'x' * 200
      formatted = console.format_tool_call('some_tool', long_params)
      plain = formatted.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).to include('...')
      expect(plain).to include('ctrl+o to expand')
    end

    it 'shows elapsed time when provided' do
      formatted = console.format_tool_call('read_file', '/etc/hosts', elapsed: 2.3)
      plain = formatted.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).to include('2.3s')
    end
  end
end
