# frozen_string_literal: true

module Antigravity
  module Jev
    class Response
      attr_reader :model, :answers, :usage, :latency_ms, :raw_data

      def initialize(data:, latency_ms:)
        @raw_data = data
        @model = data['model'] || data[:model]
        @answers = (data['answers'] || data[:answers] || {}).transform_keys(&:to_sym)
        @usage = data['usage'] || data[:usage] || {}
        @latency_ms = latency_ms
      end

      def noul(key)
        ans = @answers[key.to_sym]
        return nil unless ans

        val = ans['noul'] || ans[:noul]
        val&.to_f
      end

      def choice(key)
        ans = @answers[key.to_sym]
        return nil unless ans

        ans['choice'] || ans[:choice]
      end

      def confidence(key)
        ans = @answers[key.to_sym]
        return nil unless ans

        val = ans['confidence'] || ans[:confidence]
        val&.to_f
      end

      def score(key)
        ans = @answers[key.to_sym]
        return nil unless ans

        val = ans['score'] || ans[:score]
        val&.to_f
      end
    end
  end
end
