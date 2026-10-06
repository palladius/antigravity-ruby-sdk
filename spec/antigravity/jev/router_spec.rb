# frozen_string_literal: true

require 'spec_helper'
require 'antigravity/jev'
require 'antigravity/jev/router'

RSpec.describe Antigravity::Jev::Router do
  let(:client) { Antigravity::Jev::Client.new(mock: true) }
  let(:router) { described_class.new(client: client) }

  describe '#route' do
    it 'routes simple prompt to flash model' do
      client.set_mock_handler do |_state, _questions|
        {
          category: { type: 'choice', choice: 'simple', confidence: 0.96 }
        }
      end

      result = router.route('Show me the list of this folder')
      expect(result.model).to eq('gemini-3.8-flash-low')
      expect(result.complexity).to eq('simple')
      expect(result.confidence).to eq(0.96)
      expect(result.latency_ms).to be_a(Numeric)
    end

    it 'routes complex prompt to pro model' do
      client.set_mock_handler do |_state, _questions|
        {
          category: { type: 'choice', choice: 'complex', confidence: 0.91 }
        }
      end

      result = router.route('Refactor this whole architecture to distributed event-driven microservices')
      expect(result.model).to eq('gemini-3.8-flash-high')
      expect(result.complexity).to eq('complex')
      expect(result.confidence).to eq(0.91)
    end
  end
end
