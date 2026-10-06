# frozen_string_literal: true

module Antigravity
  module Jev
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class ApiError < Error; end
    class GuardrailBlockedError < Error; end
  end
end
