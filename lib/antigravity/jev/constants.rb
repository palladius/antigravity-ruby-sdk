# frozen_string_literal: true

require 'yaml'

module Antigravity
  module Jev
    CONFIG_FILE_PATHS = [
      File.expand_path('config/jevity.yml', Dir.pwd),
      File.expand_path('~/.config/jevity/config.yml'),
      File.expand_path('~/.jevity.yml')
    ].freeze

    class << self
      def loaded_yaml_config
        @loaded_yaml_config ||= begin
          cfg = {}
          CONFIG_FILE_PATHS.each do |path|
            next unless File.file?(path)

            begin
              data = YAML.safe_load(File.read(path))
              cfg = data if data.is_a?(Hash)
              break
            rescue StandardError
              # Ignore YAML syntax errors
            end
          end
          cfg
        end
      end

      def fast_model
        ENV['JEV_FAST_MODEL'] ||
          ENV['GEMINI_FAST_MODEL'] ||
          loaded_yaml_config['fast_model'] ||
          loaded_yaml_config['models']&.dig('fast') ||
          'gemini-3.8-flash-low'
      end

      def smart_model
        ENV['JEV_SMART_MODEL'] ||
          ENV['GEMINI_SMART_MODEL'] ||
          loaded_yaml_config['smart_model'] ||
          loaded_yaml_config['models']&.dig('smart') ||
          'gemini-3.8-flash-high'
      end

      # Used when the routed model fails (404 / 503 high demand / timeout).
      # May be a comma-separated chain, e.g. "gemini-3.7-flash,gemini-3.5-flash".
      def fallback_model
        ENV['JEV_FALLBACK_MODEL'] || loaded_yaml_config['fallback_model'] || 'gemini-3.7-flash,gemini-3.5-flash'
      end

      # Seconds to wait for a Gemini answer before failing over. Short on purpose:
      # an overloaded model that hangs is worse than a quick fallback.
      def gemini_timeout
        (ENV['JEV_GEMINI_TIMEOUT'] || loaded_yaml_config['gemini_timeout'] || 10).to_i
      end

      def allow_threshold
        (ENV['JEV_ALLOW_THRESHOLD'] || loaded_yaml_config['allow_threshold'] || 0.80).to_f
      end

      def deny_threshold
        (ENV['JEV_DENY_THRESHOLD'] || loaded_yaml_config['deny_threshold'] || 0.40).to_f
      end
    end
  end
end
