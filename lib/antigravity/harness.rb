# frozen_string_literal: true

require "open3"
require "socket"

module Antigravity
  class Harness
    attr_reader :port, :pid, :bin_path

    def initialize(bin_path: nil, port: nil)
      @bin_path = bin_path || Antigravity.config.harness_path
      @port = port || find_free_port
      @pid = nil
    end

    def start!
      return if running?

      unless File.exist?(@bin_path) && File.executable?(@bin_path)
        # Mock mode or fallback if localharness executable is missing
        warn "[Antigravity::Harness] Warning: localharness binary not found at #{@bin_path}. Running in mock mode."
        return true
      end

      cmd = "#{@bin_path} --port=#{@port}"
      @stdin, @stdout, @stderr, wait_thr = Open3.popen3(cmd)
      @pid = wait_thr.pid

      at_exit { stop! }
      true
    end

    def stop!
      return unless running?

      Process.kill("TERM", @pid) rescue nil
      @pid = nil
    end

    def running?
      !@pid.nil?
    end

    private

    def find_free_port
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close
      port
    end
  end
end
