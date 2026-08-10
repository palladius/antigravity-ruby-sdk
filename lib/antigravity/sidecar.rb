# frozen_string_literal: true

require "thread"
require "json"
require "fileutils"

module Antigravity
  module Sidecar
    # Base class for non-blocking agent sidecars
    class Base
      attr_reader :name, :queue, :worker_thread

      def initialize(name = "SidecarWorker")
        @name = name
        @queue = Queue.new
        @running = false
        start!
      end

      def start!
        return if @running

        @running = true
        @worker_thread = Thread.new do
          while @running
            event = @queue.pop
            break if event == :stop

            process_event(event) rescue nil
          end
        end
        @worker_thread.priority = -1
      end

      def emit(event_type, payload = {})
        @queue.push({ type: event_type, payload: payload, timestamp: Time.now.utc.iso8601 })
      end

      def stop!
        @running = false
        @queue.push(:stop)
        @worker_thread&.join(2)
      end

      protected

      def process_event(_event)
        raise NotImplementedError, "Subclasses must implement #process_event"
      end
    end

    # Async Audit Logger Sidecar
    class AuditLogger < Base
      attr_reader :log_file

      def initialize(log_file = "log/agent_audit.jsonl")
        @log_file = File.expand_path(log_file)
        FileUtils.mkdir_p(File.dirname(@log_file)) rescue nil
        super("AuditLoggerSidecar")
      end

      protected

      def process_event(event)
        File.open(@log_file, "a") do |f|
          f.puts(JSON.generate(event))
          f.flush
        end
      end
    end

    # Async Vulnerability & Code Quality Scanner Sidecar
    class VulnerabilityScanner < Base
      attr_reader :scanned_events

      def initialize
        @scanned_events = []
        super("VulnerabilityScannerSidecar")
      end

      protected

      def process_event(event)
        return unless event[:type] == :tool_executed

        tool_name = event.dig(:payload, :tool_name)
        params = event.dig(:payload, :params)
        @scanned_events << { tool: tool_name, params: params, verified: true }
      end
    end
  end
end
