# frozen_string_literal: true

module Antigravity
  class Config
    attr_accessor :api_key, :default_model, :harness_path, :log_level

    # Timeouts (seconds) — aggressive for dev, override via ENV for prod.
    #   ANTIGRAVITY_TIMEOUT_LLM       — per-message wait for LLM response (default: 20s)
    #   ANTIGRAVITY_TIMEOUT_WS        — WebSocket connect/handshake (default: 3s)
    #   ANTIGRAVITY_TIMEOUT_HANDSHAKE — stdio binary handshake (default: 5s)
    attr_accessor :timeout_llm, :timeout_ws, :timeout_handshake

    def initialize
      @api_key = ENV["GEMINI_API_KEY"]
      @default_model = ENV["GEMINI_MODEL"] || ENV["ANTIGRAVITY_MODEL"] || "gemini-2.5-flash-lite"
      @harness_path = ENV["ANTIGRAVITY_HARNESS_PATH"] || File.expand_path("~/.antigravity/bin/localharness")
      @log_level = :info

      # Timeouts: aggressive for dev, relax via ENV for production
      @timeout_llm       = (ENV["ANTIGRAVITY_TIMEOUT_LLM"]       || 20).to_i
      @timeout_ws        = (ENV["ANTIGRAVITY_TIMEOUT_WS"]        || 3).to_i
      @timeout_handshake = (ENV["ANTIGRAVITY_TIMEOUT_HANDSHAKE"] || 5).to_i
    end

    def api_key?
      !@api_key.nil? && !@api_key.empty?
    end
  end
end
