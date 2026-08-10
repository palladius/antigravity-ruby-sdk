# frozen_string_literal: true

require_relative "antigravity/version"
require_relative "antigravity/config"
require_relative "antigravity/message"
require_relative "antigravity/harness"
require_relative "antigravity/hooks"
require_relative "antigravity/safety"
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
