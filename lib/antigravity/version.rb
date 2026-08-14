# frozen_string_literal: true

module Antigravity
  VERSION = begin
    version_file = [
      File.expand_path("../../VERSION", __dir__),
      File.expand_path("../VERSION", __dir__)
    ].find { |f| File.exist?(f) }
    version_file ? File.read(version_file).strip : "0.5.0"
  end
end
