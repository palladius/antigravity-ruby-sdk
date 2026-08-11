# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tmpdir'

module Antigravity
  module Connection
    # Manages the full lifecycle of communicating with the localharness Go binary.
    #
    # Lifecycle: discover → spawn → stdio handshake → WebSocket → events → shutdown
    #
    # The localharness binary is the core Go engine that powers Antigravity.
    # It handles model calls, tool orchestration, and agent logic.
    # This class is the Ruby adapter that speaks its protocol.
    class LocalConnection < Base
      # Known locations for the localharness binary (checked in order).
      # IMPORTANT: The standalone `localharness` binary (from PyPI wheel) uses
      # the stdin/stdout protobuf handshake. The `language_server` binary
      # (Antigravity.app) does NOT — it's the IDE server mode.
      BINARY_SEARCH_PATHS = [
        File.expand_path('~/.antigravity/bin/localharness'),
        File.expand_path('~/.local/bin/localharness'),
      ].freeze

      HARNESS_SUBCOMMAND = 'localharness'

      attr_reader :port, :api_key, :pid

      def initialize(binary_path: nil)
        @binary_path = binary_path || self.class.find_binary!
        @port = nil
        @api_key = nil
        @pid = nil
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @connected = false
      end

      # --- Binary Discovery ---

      # Finds the localharness binary. Search order:
      #   1. ANTIGRAVITY_HARNESS_PATH env var
      #   2. Antigravity.app (macOS)
      #   3. ~/.antigravity/bin/
      #   4. PATH lookup via `which`
      #   5. Auto-download from PyPI (unless ANTIGRAVITY_AUTO_DOWNLOAD=false)
      #
      # @return [String] absolute path to the binary
      # @raise [HarnessNotFoundError] if not found anywhere
      def self.find_binary!
        # 1. Env var override
        if (env_path = ENV['ANTIGRAVITY_HARNESS_PATH'])
          return env_path if File.executable?(env_path)

          raise HarnessNotFoundError,
            "ANTIGRAVITY_HARNESS_PATH=#{env_path} is not executable"
        end

        # 2. Known paths
        BINARY_SEARCH_PATHS.each do |path|
          return path if File.executable?(path)
        end

        # 3. PATH lookup
        which_result = `which localharness 2>/dev/null`.strip
        return which_result unless which_result.empty?

        # 4. Auto-download from PyPI wheel (opt-out with ANTIGRAVITY_AUTO_DOWNLOAD=false)
        auto_dl = ENV.fetch('ANTIGRAVITY_AUTO_DOWNLOAD', 'true').downcase
        unless %w[false 0 no].include?(auto_dl)
          $stderr.puts "⏳ localharness not found locally. Downloading from PyPI... this may take a minute."
          return BinaryFetcher.fetch!
        end

        raise HarnessNotFoundError,
          "Could not find localharness binary. Install Antigravity.app, set ANTIGRAVITY_HARNESS_PATH, or allow auto-download."
      end

      # --- Connection Lifecycle ---

      def connect!
        spawn_process!
        perform_handshake!
        connect_websocket!
        @connected = true
        self
      end

      def connected?
        @connected && process_alive? && @ws_client&.connected?
      end

      def disconnect!
        @connected = false
        @ws_client&.close
        kill_process!
      end

      # Expose the WebSocket client for Conversation to use
      def ws_client
        @ws_client
      end

      private

      def spawn_process!
        # Only pass 'localharness' subcommand when binary is language_server
        # (Antigravity.app). The standalone localharness binary needs no subcommand.
        cmd = if @binary_path.end_with?('language_server')
                [@binary_path, HARNESS_SUBCOMMAND]
              else
                [@binary_path]
              end

        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(*cmd)
        @pid = @wait_thread.pid
      rescue Errno::ENOENT => e
        raise HarnessNotFoundError, "Failed to spawn localharness: #{e.message}"
      end

      def perform_handshake!
        storage_dir = File.join(Dir.tmpdir, "antigravity-ruby-#{$$}")
        FileUtils.mkdir_p(storage_dir)

        # Send InputConfig via stdin
        input_config = Protocol.encode_input_config(
          storage_directory: storage_dir,
          bind_address: 'localhost'
        )
        @stdin.write(input_config)
        @stdin.flush

        # Read OutputConfig from stdout
        frame = Protocol.read_length_prefixed(@stdout, timeout: Antigravity.config.timeout_handshake)
        output = Protocol.decode_output_config(frame)
        @port = output[:port]
        @api_key = output[:api_key]

        raise HarnessHandshakeError, "Harness returned port=0" if @port == 0
      rescue IOError, Errno::EPIPE, ProtocolError => e
        # Capture stderr for diagnostics
        stderr_output = begin
          @stderr&.read_nonblock(4096)
        rescue EOFError, IOError, Errno::EAGAIN
          nil
        end
        kill_process!
        detail = stderr_output ? " Stderr: #{stderr_output.strip}" : ''
        raise HarnessHandshakeError, "Stdio handshake failed: #{e.message}#{detail}"
      end

      def connect_websocket!
        @ws_client = WebSocketClient.new(port: @port, api_key: @api_key)
        @ws_client.connect!
      rescue => e
        kill_process!
        raise ProtocolError, "WebSocket connection failed: #{e.message}"
      end

      def process_alive?
        return false unless @pid

        Process.kill(0, @pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      def kill_process!
        [@stdin, @stdout, @stderr].each { |io| io&.close rescue nil }
        Process.kill('TERM', @pid) if @pid && process_alive?
        @wait_thread&.join(5)
        Process.kill('KILL', @pid) if @pid && process_alive?
      rescue Errno::ESRCH, Errno::EPERM
        # Already dead, fine
      ensure
        @pid = nil
        @stdin = @stdout = @stderr = nil
      end
    end
  end
end
