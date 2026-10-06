# frozen_string_literal: true

require_relative "jev/errors"
require_relative "jev/response"
require_relative "jev/client"

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
