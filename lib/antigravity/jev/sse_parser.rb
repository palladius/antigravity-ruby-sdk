# frozen_string_literal: true

require 'json'

module Antigravity
  module Jev
    # Incremental Server-Sent Events parser for Gemini's `?alt=sse` stream.
    # Feed raw (binary) chunks; complete `data: {json}` lines are yielded as Hashes.
    class SseParser
      def initialize(&on_event)
        @on_event = on_event
        @buffer = String.new(encoding: Encoding::BINARY)
      end

      def feed(chunk)
        @buffer << chunk.to_s.b
        while (idx = @buffer.index("\n"))
          line = @buffer.slice!(0..idx).force_encoding(Encoding::UTF_8).strip
          emit(line)
        end
      end

      private

      def emit(line)
        return unless line.start_with?('data:')

        @on_event.call(JSON.parse(line.delete_prefix('data:').strip))
      rescue JSON::ParserError
        nil # malformed event: skip it, keep streaming
      end
    end
  end
end
