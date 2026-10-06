# frozen_string_literal: true

require_relative '../colors'

module Antigravity
  module Jev
    module Telemetry
      class << self
        def format_command_verdict(verdict, command, latency_ms:, probability:, color: $stdout.tty?)
          safe_pct = (probability.to_f * 100.0).round(1)
          lat_str = "#{latency_ms.to_f.round(1)}ms"

          badge = "[Jev: #{lat_str} | Safe: #{safe_pct}%]"
          badge_str = color ? Colors.colorize(badge, :yellow, :bold) : badge

          case verdict.to_sym
          when :allow, :approved
            label = 'APPROVED'
            label_str = color ? Colors.colorize(label, :bright_green, :bold) : label
            "⚡ #{badge_str} ✅ #{label_str}: #{command}"
          when :ask, :unsure
            label = 'UNSURE'
            label_str = color ? Colors.colorize(label, :bright_yellow, :bold) : label
            "⚡ #{badge_str} ⚠️ #{label_str}: #{command}"
          when :deny, :blocked
            label = 'BLOCKED'
            label_str = color ? Colors.colorize(label, :red, :bold) : label
            "⚡ #{badge_str} 🚫 #{label_str}: #{command}"
          else
            "⚡ #{badge_str} ℹ️ #{verdict.to_s.upcase}: #{command}"
          end
        end

        def format_routing(complexity, model, latency_ms:, confidence:, color: $stdout.tty?)
          conf_pct = (confidence.to_f * 100.0).round(1)
          lat_str = "#{latency_ms.to_f.round(1)}ms"

          badge = "[Jev: #{lat_str} | Routing: #{complexity} (#{conf_pct}%)]"
          badge_str = color ? Colors.colorize(badge, :yellow, :bold) : badge

          icon = complexity.to_s == 'complex' ? '🧠' : '🚀'
          routed_label = color ? Colors.colorize('ROUTED', :cyan, :bold) : 'ROUTED'

          "⚡ #{badge_str} #{icon} #{routed_label}: #{model}"
        end
      end
    end
  end
end
