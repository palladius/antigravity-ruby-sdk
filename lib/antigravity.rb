# frozen_string_literal: true

begin
  require "dotenv/load" if File.exist?(".env")
rescue LoadError
  # Safe fallback if dotenv gem is not installed in the project
end

require_relative "antigravity/version"
require_relative "antigravity/emojis"
require_relative "antigravity/base"
require_relative "antigravity/errors"
require_relative "antigravity/config"
require_relative "antigravity/message"
require_relative "antigravity/protocol"
require_relative "antigravity/harness"
require_relative "antigravity/policy"
require_relative "antigravity/hooks"
require_relative "antigravity/guards"
require_relative "antigravity/sidecar"
require_relative "antigravity/tool"
require_relative "antigravity/tool_runner"
require_relative "antigravity/skill_resolver"
require_relative "antigravity/skill"
require_relative "antigravity/client"
require_relative "antigravity/connection/binary_fetcher"
require_relative "antigravity/connection/websocket_client"
require_relative "antigravity/connection/local_connection"
require_relative "antigravity/conversation"
require_relative "antigravity/colors"
require_relative "antigravity/lifecycle_logger"
require_relative "antigravity/agent"

module Antigravity
  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Config.new
    end

    # One-liner top-level prompt helper
    #   Antigravity.ask("What is 2+2?")
    #   Antigravity.ask("Explain Ruby", policy: :cautious) { |chunk| print chunk.content }
    def ask(prompt, **kwargs, &block)
      Agent.ask(prompt, **kwargs, &block)
    end

    # Top-level tool definition helper
    #   Antigravity.tool(:weather, desc: "Get city weather") { |city:| "22°C in #{city}" }
    def tool(name, desc: "", params: {}, &block)
      Tool.define(name, desc: desc, params: params, &block)
    end

    # Top-level policy definition helper
    #   Antigravity.policy { allow :read_file }
    def policy(&block)
      Policy.define(&block)
    end
  end
end
