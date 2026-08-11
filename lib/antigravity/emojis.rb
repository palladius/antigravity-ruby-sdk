# frozen_string_literal: true

module Antigravity
  EMOJIS = {
    gem: "💎",
    agent: "🕵️‍♂️",
    prompt: "💬",
    response: "🤖",
    thinking: "🤔",
    tool: "🛠️",
    tool_result: "📦",
    tool_blocked: "❌",
    sidecar: "🚗",
    logger: "🪵",
    skill: "📁",
    message: "💬",
    guard: "🛡️",
    test: "🧪",
    success: "✅",
    unknown: "🤷"
  }.freeze

  # Name fragments we recognise in the class hierarchy
  EMOJI_CLASS_MAP = {
    "Agent" => :agent,
    "Tool" => :tool,
    "Sidecar" => :sidecar,
    "Runner" => :sidecar,
    "Skill" => :skill,
    "Message" => :message,
    "Chunk" => :message,
    "Guard" => :guard,
    "Logger" => :logger
  }.freeze

  class << self
    def emoji(key)
      EMOJIS[key.to_sym] || EMOJIS[:unknown]
    end

    def emoji_for(target)
      key = resolve_emoji_key(target)
      emoji(key)
    end

    private

    def resolve_emoji_key(target)
      # Message/Chunk: role-aware
      if target.is_a?(Message) || (defined?(Chunk) && target.is_a?(Chunk))
        return target.respond_to?(:role) && target.role == :user ? :prompt : :response
      end

      # Direct symbol/string lookup
      return target if target.is_a?(Symbol) || target.is_a?(String)

      # Class hierarchy reflection
      klass = target.is_a?(Class) || target.is_a?(Module) ? target : target.class
      parts = klass.name&.split("::") || []
      parts.reverse_each do |part|
        return EMOJI_CLASS_MAP[part] if EMOJI_CLASS_MAP.key?(part)
      end

      :unknown
    end
  end

  # Mixin providing polymorphic .emoji class and #emoji instance methods.
  # Auto-included by Antigravity::Base via inherited hook.
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
