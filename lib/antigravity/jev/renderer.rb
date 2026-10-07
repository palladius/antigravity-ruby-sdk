# frozen_string_literal: true

require_relative '../colors'

module Antigravity
  module Jev
    # Renders model output in a terminal-friendly, tag-free layout:
    #
    #   🤔 first line of thinking        (gray)
    #     continuation line              (gray, indented)
    #   🤖 first line of the answer      (white)
    #     continuation line              (white, indented)
    #
    # Color is an explicit flag (not $stdout.tty?) so it works with any IO
    # and stays plain when piped.
    class Renderer
      THINKING_EMOJI = '🤔'
      ANSWER_EMOJI   = '🤖'
      WARNING_EMOJI  = '⚠️ '
      INDENT         = '  ' # edit me: continuation-line indent
      CODE_FENCE     = /```(?:bash|sh|shell)?[ \t]*\n.*?\n```/m

      def initialize(output: $stdout, color: nil)
        @output = output
        @color = color.nil? ? (output.respond_to?(:tty?) && output.tty?) : color
      end

      def thinking(text)
        block(THINKING_EMOJI, text, :gray)
      end

      def answer(text)
        block(ANSWER_EMOJI, text.to_s.gsub(CODE_FENCE, ''), :white)
      end

      def warning(text)
        block(WARNING_EMOJI, text, :yellow)
      end

      private

      def block(emoji, text, style)
        lines = text.to_s.strip.lines.map(&:rstrip).reject(&:empty?)
        return if lines.empty?

        lines.each_with_index do |line, i|
          prefix = i.zero? ? "#{emoji} " : INDENT
          @output.puts "#{prefix}#{paint(line, style)}"
        end
      end

      def paint(text, style)
        return text unless @color

        "#{Colors::CODES[style]}#{text}#{Colors::CODES[:reset]}"
      end
    end
  end
end
