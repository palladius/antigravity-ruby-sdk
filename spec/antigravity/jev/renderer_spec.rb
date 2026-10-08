# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'

RSpec.describe Antigravity::Jev::Renderer do
  let(:output) { StringIO.new }

  context 'with color enabled' do
    let(:renderer) { described_class.new(output: output, color: true) }

    it 'renders thinking with 🤔 prefix, gray color and indented continuation lines' do
      renderer.thinking("First idea\nSecond idea")
      lines = output.string.lines.map(&:chomp)

      expect(lines[0]).to eq("🤔 \e[90mFirst idea\e[0m")
      expect(lines[1]).to eq("#{described_class::INDENT}\e[90mSecond idea\e[0m")
    end

    it 'renders answer with 🤖 prefix, white color and indented continuation lines' do
      renderer.answer("Ecco il repo\nHa tre cartelle")
      lines = output.string.lines.map(&:chomp)

      expect(lines[0]).to eq("🤖 \e[37mEcco il repo\e[0m")
      expect(lines[1]).to eq("#{described_class::INDENT}\e[37mHa tre cartelle\e[0m")
    end

    it 'strips bash code fences from the answer (command is shown by the guardrail line)' do
      renderer.answer("Listo i file:\n```bash\nls -la\n```")
      expect(output.string).to include('Listo i file:')
      expect(output.string).not_to include('```')
      expect(output.string).not_to include('ls -la')
    end

    it 'renders warnings with ⚠️ in yellow' do
      renderer.warning('Gemini HTTP 503')
      expect(output.string).to eq("⚠️  \e[33mGemini HTTP 503\e[0m\n")
    end

    it 'renders network errors with 🔌 in red' do
      renderer.network_error('JEV unreachable')
      expect(output.string).to eq("🔌 \e[31mJEV unreachable\e[0m\n")
    end

    it 'routes connectivity warnings (Net::ReadTimeout & co) to the red 🔌 style' do
      renderer.warning('gemini-3.7-flash: no answer within 6s (Net::ReadTimeout)')
      expect(output.string).to start_with("🔌 \e[31m")
    end
  end

  context 'with color disabled (pipes / non-TTY)' do
    let(:renderer) { described_class.new(output: output, color: false) }

    it 'emits no ANSI escape codes' do
      renderer.thinking("a\nb")
      renderer.answer('c')
      expect(output.string).not_to include("\e[")
      expect(output.string).to eq("🤔 a\n#{described_class::INDENT}b\n🤖 c\n")
    end
  end

  it 'ignores blank text' do
    renderer = described_class.new(output: output, color: false)
    renderer.thinking(nil)
    renderer.answer("  \n ")
    expect(output.string).to eq('')
  end

  describe '#waiting ⏳' do
    it 'shows a transient hourglass line on a TTY and erases it after the block' do
      renderer = described_class.new(output: output, color: true)
      result = renderer.waiting('gemini-3.8-flash') { :done }

      expect(result).to eq(:done)
      expect(output.string).to start_with("\r⏳ ")
      expect(output.string).to include('gemini-3.8-flash')
      expect(output.string).to end_with("\r\e[K")
    end

    it 'erases the line even if the block raises' do
      renderer = described_class.new(output: output, color: true)
      expect { renderer.waiting('x') { raise 'boom' } }.to raise_error('boom')
      expect(output.string).to end_with("\r\e[K")
    end

    it 'prints nothing when piped (no color)' do
      renderer = described_class.new(output: output, color: false)
      expect(renderer.waiting('x') { 42 }).to eq(42)
      expect(output.string).to eq('')
    end
  end

  describe '#stream 🌊' do
    let(:renderer) { described_class.new(output: output, color: false) }

    it 'prints deltas line by line with 🤔 / 🤖 prefixes and indented continuations' do
      s = renderer.stream('x')
      s.write(:thought, "Pen")
      s.write(:thought, "so\nancora\n")
      s.write(:text, "Ecco il\nrepo")
      expect(output.string).to eq("🤔 Penso\n  ancora\n🤖 Ecco il\n")
      s.finish
      expect(output.string).to eq("🤔 Penso\n  ancora\n🤖 Ecco il\n  repo\n")
      expect(s.emitted?).to be true
    end

    it 'hides ```bash fenced blocks (including ```bash final)' do
      s = renderer.stream('x')
      s.write(:text, "Listo:\n```bash final\nls -la\n```\nFatto")
      s.finish
      expect(output.string).to eq("🤖 Listo:\n  Fatto\n")
    end

    it 'prints warnings on their own line and restarts the next section with its emoji' do
      s = renderer.stream('x')
      s.write(:text, "mezza")
      s.write(:warning, 'HTTP 503')
      s.write(:text, "nuova\n")
      s.finish
      expect(output.string).to eq("🤖 mezza\n⚠️  HTTP 503\n🤖 nuova\n")
    end

    it 'reports nothing emitted when no deltas arrived' do
      s = renderer.stream('x')
      s.finish
      expect(s.emitted?).to be false
      expect(output.string).to eq('')
    end

    it 'shows ⏳ until the first line arrives (TTY), then erases it' do
      tty = described_class.new(output: output, color: true)
      s = tty.stream('gemini-3.7-flash')
      expect(output.string).to start_with("\r⏳ ")
      s.write(:text, "ciao\n")
      expect(output.string).to include("\r\e[K🤖 ")
      s.finish
    end
  end
end
