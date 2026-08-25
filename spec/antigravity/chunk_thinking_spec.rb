# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Thinking Token Streaming' do
  describe Antigravity::Chunk do
    describe '#thinking?' do
      it 'returns true when chunk has thinking content' do
        chunk = Antigravity::Chunk.new(thinking: 'analyzing the problem...')
        expect(chunk.thinking?).to be true
      end

      it 'returns false when chunk has no thinking content' do
        chunk = Antigravity::Chunk.new(content: 'Hello!')
        expect(chunk.thinking?).to be false
      end

      it 'returns false for empty thinking string' do
        chunk = Antigravity::Chunk.new(thinking: '')
        expect(chunk.thinking?).to be false
      end

      it 'returns false for nil thinking' do
        chunk = Antigravity::Chunk.new(thinking: nil)
        expect(chunk.thinking?).to be false
      end
    end

    describe '#content?' do
      it 'returns true when chunk has content' do
        chunk = Antigravity::Chunk.new(content: 'Hello!')
        expect(chunk.content?).to be true
      end

      it 'returns false when chunk has no content' do
        chunk = Antigravity::Chunk.new(thinking: 'hmm...')
        expect(chunk.content?).to be false
      end

      it 'returns false for empty content string' do
        chunk = Antigravity::Chunk.new(content: '')
        expect(chunk.content?).to be false
      end
    end

    it 'can carry both thinking and content' do
      chunk = Antigravity::Chunk.new(content: 'Hi', thinking: 'pondering...')
      expect(chunk.thinking?).to be true
      expect(chunk.content?).to be true
    end

    it 'is always a delta' do
      chunk = Antigravity::Chunk.new(thinking: 'hmm')
      expect(chunk.delta?).to be true
    end
  end
end
