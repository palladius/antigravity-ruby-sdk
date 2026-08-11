# frozen_string_literal: true

require 'socket'
require 'websocket'
require 'json'
require 'securerandom'

module Antigravity
  module Connection
    # Lightweight WebSocket client for the localharness.
    # Uses the `websocket` gem for frame encoding/decoding over raw TCPSocket.
    # No EventMachine, no threads-by-default — just blocking IO.
    class WebSocketClient
      attr_reader :port, :api_key, :connected

      def initialize(port:, api_key:)
        @port = port
        @api_key = api_key
        @socket = nil
        @handshake = nil
        @connected = false
        @frame_buffer = WebSocket::Frame::Incoming::Client.new
      end

      # Open the WebSocket connection to ws://localhost:<port>/
      def connect!
        @socket = TCPSocket.new('127.0.0.1', @port)

        # Build and send the HTTP upgrade handshake
        @handshake = WebSocket::Handshake::Client.new(
          url: "ws://127.0.0.1:#{@port}/",
          headers: { 'x-goog-api-key' => @api_key }
        )
        @socket.write(@handshake.to_s)
        @socket.flush

        # Read the server's handshake response
        loop do
          line = @socket.gets
          raise ProtocolError, 'EOF during WebSocket handshake' unless line

          @handshake << line
          break if @handshake.finished?
        end

        unless @handshake.valid?
          raise ProtocolError, "WebSocket handshake rejected: #{@handshake.error}"
        end

        @connected = true
        self
      end

      def connected?
        @connected && @socket && !@socket.closed?
      end

      # Send a JSON message as a WebSocket text frame
      def send_json(data)
        json = data.is_a?(String) ? data : JSON.generate(data)
        frame = WebSocket::Frame::Outgoing::Client.new(
          data: json,
          type: :text,
          version: @handshake.version
        )
        @socket.write(frame.to_s)
        @socket.flush
      end

      # Read the next JSON message. Blocks until a text frame arrives.
      # Yields each message if a block is given (for streaming).
      # Returns nil on connection close or idle_timeout.
      def receive_json(timeout: Antigravity.config.timeout_llm, idle_timeout: nil)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        last_activity = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        loop do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          remaining = deadline - now
          raise ProtocolError, 'WebSocket read timeout' if remaining <= 0

          if idle_timeout && (now - last_activity) >= idle_timeout
            return nil
          end

          select_time = [remaining, 0.5].min
          if idle_timeout
            idle_rem = idle_timeout - (now - last_activity)
            select_time = [select_time, idle_rem].min if idle_rem > 0
          end

          ready = IO.select([@socket], nil, nil, [select_time, 0.05].max)
          next unless ready

          data = @socket.read_nonblock(16384, exception: false)
          case data
          when :wait_readable then next
          when nil
            @connected = false
            return nil
          end

          last_activity = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @frame_buffer << data

          while (frame = @frame_buffer.next)
            case frame.type
            when :text
              return JSON.parse(frame.data, symbolize_names: true)
            when :ping
              pong = WebSocket::Frame::Outgoing::Client.new(
                data: frame.data, type: :pong, version: @handshake.version
              )
              @socket.write(pong.to_s)
            when :close
              @connected = false
              return nil
            end
          end
        end
      end

      # Read messages in a loop, yielding each parsed JSON.
      # Stops when block returns :stop, connection closes, or timeout.
      def each_message(timeout: Antigravity.config.timeout_llm, &block)
        loop do
          # Block can return [:stop] or [:idle_timeout, seconds]
          msg = receive_json(timeout: timeout, idle_timeout: @current_idle_timeout)
          break unless msg

          result = block.call(msg)
          if result.is_a?(Array) && result.first == :idle_timeout
            @current_idle_timeout = result.last
          elsif result == :stop
            @current_idle_timeout = nil
            break
          end
        end
      ensure
        @current_idle_timeout = nil
      end

      def close
        return unless @socket && !@socket.closed?

        begin
          close_frame = WebSocket::Frame::Outgoing::Client.new(
            data: '', type: :close, version: @handshake&.version || 13
          )
          @socket.write(close_frame.to_s)
        rescue IOError, Errno::EPIPE
          # Already closed
        end
        @socket.close rescue nil
        @connected = false
      end
    end
  end
end
