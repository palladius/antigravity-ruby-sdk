# frozen_string_literal: true

begin
  require "dotenv/load" if File.exist?(".env")
rescue LoadError
  # Safe fallback if dotenv gem is not installed in the project
end

require_relative "antigravity/version"
require_relative "antigravity/emojis"
require_relative "antigravity/config"
require_relative "antigravity/message"
require_relative "antigravity/harness"
require_relative "antigravity/hooks"
require_relative "antigravity/guards"
require_relative "antigravity/sidecar"
require_relative "antigravity/tool"
require_relative "antigravity/skill"
require_relative "antigravity/client"
require_relative "antigravity/agent"

module Antigravity
  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Config.new
    end
  end
end
