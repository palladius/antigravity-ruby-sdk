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
end
