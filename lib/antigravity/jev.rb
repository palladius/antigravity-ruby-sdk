# frozen_string_literal: true

require_relative 'jev/errors'
require_relative 'jev/constants'
require_relative 'jev/response'
require_relative 'jev/client'
require_relative 'jev/telemetry'
require_relative 'jev/router'
require_relative 'jev/guardrail'
require_relative 'jev/harness'

module Antigravity
  module Jev
    class << self
      def client(api_key: nil, mock: false)
        @client ||= Client.new(api_key: api_key, mock: mock)
      end

      def reset_client!
        @client = nil
      end
    end
  end
end
