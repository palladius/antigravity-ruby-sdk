# frozen_string_literal: true

module Antigravity
  EMOJIS = {
    gem: "💎",
    agent: "💎",
    prompt: "💬",
    response: "🤖",
    thinking: "🤔",
    tool: "🛠️",
    tool_result: "📦",
    tool_blocked: "❌",
    sidecar: "🚗",
    logger: "🪵",
    skill: "📁",
    guard: "🛡️",
    test: "🧪",
    success: "✅"
  }.freeze

  class << self
    def emoji(key)
      EMOJIS[key.to_sym] || "💎"
    end

    def emoji_for(target)
      key = case target
            when Message, Chunk
              target.respond_to?(:role) && target.role == :user ? :prompt : :response
            when Symbol, String
              target
            else
              klass = target.is_a?(Class) || target.is_a?(Module) ? target : target.class
              matched_part = klass.name&.split("::")&.reverse&.find do |part|
                %w[Agent Tool Sidecar Skill Message Guard Logger].include?(part)
              end
              matched_part ? matched_part.downcase.to_sym : :gem
            end

      emoji(key)
    end
  end

  # Mixin providing polymorphic .emoji class and instance methods
  module Emojifiable
    def emoji
      Antigravity.emoji_for(self)
    end

    module ClassMethods
      def emoji
        Antigravity.emoji_for(self)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
