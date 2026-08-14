# frozen_string_literal: true

require_relative "lib/antigravity/version"

Gem::Specification.new do |spec|
  spec.name          = "antigravity-sdk"
  spec.version       = Antigravity::VERSION
  spec.authors       = ["Riccardo Carlesso"]
  spec.email         = ["ricc@google.com"]

  spec.summary       = "Google Antigravity SDK for Ruby"
  spec.description   = "An elegant, Ruby-like SDK for building autonomous AI agents with Google Antigravity."
  spec.homepage      = "https://github.com/palladius/antigravity-ruby-sdk"
  spec.license       = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{lib,exe}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) } + ["VERSION"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "websocket", "~> 1.2"
  spec.add_dependency "json", ">= 2.6"
  spec.add_dependency "logger", ">= 1.5"
  spec.add_dependency "dotenv", "~> 3.0"
end
