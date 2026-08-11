# frozen_string_literal: true

module Antigravity
  # Base error for all Antigravity SDK errors
  class Error < StandardError; end

  # Raised when the localharness binary cannot be found
  class HarnessNotFoundError < Error; end

  # Raised when the stdio handshake with localharness fails
  class HarnessHandshakeError < Error; end

  # Raised when protobuf encoding/decoding fails
  class ProtocolError < Error; end

  # Raised when a tool callback fails
  class ToolError < Error; end

  # Raised when trying to execute an unregistered tool
  class ToolNotFoundError < ToolError; end

  # Raised when WebSocket connection fails
  class ConnectionError < Error; end
end
