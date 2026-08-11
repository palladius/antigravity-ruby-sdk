# frozen_string_literal: true

module Antigravity
  # Base class for all Antigravity domain objects.
  # Subclasses automagically get .emoji / #emoji via Emojifiable.
  #
  # ⚠️  Keep this class SUPER thin!
  # Every SDK class inherits from it, so any weight here
  # is carried by Agent, Tool, Skill, Message, Sidecar::Runner, etc.
  class Base
    include Emojifiable

    def self.inherited(subclass)
      super
      subclass.include(Emojifiable) unless subclass < Emojifiable
    end
  end
end
