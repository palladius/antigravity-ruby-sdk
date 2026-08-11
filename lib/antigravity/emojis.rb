# frozen_string_literal: true

module Antigravity
  EMOJIS = {
    gem: "💎",
    prompt: "💬",
    response: "🤖",
    thinking: "🤔",
    tool: "🛠️",
    tool_result: "📦",
    tool_blocked: "❌",
    sidecar: "🚗",
    logger: "🪵",
    skill: "📁",
    test: "🧪",
    success: "✅"
  }.freeze

  class << self
    def emoji(key)
      EMOJIS[key.to_sym] || "💎"
    end
  end
end
