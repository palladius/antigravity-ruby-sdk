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
      CODE_FENCE     = /```[^\n]*\n.*?\n```/m

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

      # Shows "⏳ label…" while the block runs (TTY only), then erases it.
      def waiting(label)
        show_waiting(label)
        yield
      ensure
        clear_waiting
      end

      # Live renderer for streamed deltas (see Stream).
      def stream(label)
        Stream.new(self, label)
      end

      # @api private (used by Stream)
      def show_waiting(label)
        return unless @color

        @output.print "\r⏳ #{paint("#{label}…", :gray)}"
        @output.flush if @output.respond_to?(:flush)
      end

      # @api private (used by Stream)
      def clear_waiting
        @output.print "\r\e[K" if @color
      end

      # @api private (used by Stream)
      def line(prefix, text, style)
        @output.puts "#{prefix}#{paint(text, style)}"
        @output.flush if @output.respond_to?(:flush)
      end

      private

      def block(emoji, text, style)
        lines = text.to_s.strip.lines.map(&:rstrip).reject(&:empty?)
        return if lines.empty?

        lines.each_with_index do |l, i|
          line(i.zero? ? "#{emoji} " : INDENT, l, style)
        end
      end

      def paint(text, style)
        return text unless @color

        "#{Colors::CODES[style]}#{text}#{Colors::CODES[:reset]}"
      end

      # Line-buffered live printer: same layout as #thinking / #answer, but
      # each line is printed the moment it is complete. ⏳ stays until the
      # first line arrives; ``` fenced blocks are hidden (the guardrail line
      # shows the command anyway).
      class Stream
        SECTIONS = { thought: [THINKING_EMOJI, :gray], text: [ANSWER_EMOJI, :white] }.freeze

        def initialize(renderer, label)
          @r = renderer
          @kind = nil
          @buf = +''
          @first = true
          @in_fence = false
          @emitted = false
          @waiting = true
          @r.show_waiting(label)
        end

        def emitted?
          @emitted
        end

        def warned?
          @warned == true
        end

        def write(kind, text)
          return warn_line(text) if kind == :warning

          switch_to(kind) if kind != @kind
          @buf << text.to_s
          while (idx = @buf.index("\n"))
            emit(@buf.slice!(0..idx))
          end
        end

        def finish
          flush_partial
          stop_waiting
        end

        private

        def warn_line(text)
          flush_partial
          stop_waiting
          @r.warning(text)
          @warned = true
          @kind = nil
        end

        def switch_to(kind)
          flush_partial
          @kind = kind
          @first = true
          @in_fence = false
        end

        def flush_partial
          rest = @buf.dup
          @buf.clear
          emit(rest) unless rest.empty?
        end

        def emit(raw)
          text = raw.rstrip
          return @in_fence = !@in_fence if @kind == :text && text.lstrip.start_with?('```')
          return if @in_fence || text.strip.empty?

          stop_waiting
          emoji, style = SECTIONS.fetch(@kind, SECTIONS[:text])
          @r.line(@first ? "#{emoji} " : INDENT, text, style)
          @first = false
          @emitted = true
        end

        def stop_waiting
          return unless @waiting

          @waiting = false
          @r.clear_waiting
        end
      end
    end
  end
end
