# frozen_string_literal: true

require 'net/http'
require 'openssl'

module Antigravity
  module Jev
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class ApiError < Error; end
    class GuardrailBlockedError < Error; end

    # 🔌 The other side never answered (timeout, DNS, refused, reset, TLS).
    # Subclass of ApiError so existing `rescue ApiError` still catches it.
    class NetworkError < ApiError; end

    # Low-level exceptions we catch explicitly and turn into a 🔌 NetworkError.
    NETWORK_ERRORS = [
      Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout, SocketError, EOFError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      Errno::ETIMEDOUT, OpenSSL::SSL::SSLError
    ].freeze

    # Matches the class names above inside an error message (used for 🔌 rendering).
    NETWORK_ERROR_RE = Regexp.union(NETWORK_ERRORS.map(&:name) + ['unreachable', 'no answer within']).freeze
  end
end
