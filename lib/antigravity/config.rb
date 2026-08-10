# frozen_string_literal: true

module Antigravity
  class Config
    attr_accessor :api_key, :default_model, :harness_path, :log_level

    def initialize
      @api_key = ENV["GEMINI_API_KEY"]
      @default_model = "gemini-2.5-flash"
      @harness_path = ENV["ANTIGRAVITY_HARNESS_PATH"] || File.expand_path("~/.antigravity/bin/localharness")
      @log_level = :info
    end

    def api_key?
      !@api_key.nil? && !@api_key.empty?
    end
  end
end
