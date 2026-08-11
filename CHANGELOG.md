# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.1.4] - 2026-08-11 🪵
* 🪵 Added `Antigravity::Guards::AgentLogger` and `Agent#attach_logger("log/antigravity.log")` for logging prompts, responses, and tool calls to standard Ruby/Rails log targets (`log/development.log`, `Rails.logger`, or file targets).
* 📦 Added explicit `logger` dependency for Ruby 3.5+ compatibility.

## [0.1.3] - 2026-08-11 🛡️
* 🛡️ Added `Antigravity::Guards::FileProtection` (`files: [".env", "Gemfile"]`) and `Antigravity::Guards::SecretMasker` as clean, opt-in helper classes in `lib/antigravity/guards.rb`.

## [0.1.2] - 2026-08-11 🧹
* 🎨 Refactored core gem to be 100% clean and un-opinionated by removing hardcoded safety defaults from `Agent.new`.

## [0.1.1] - 2026-08-11 🛠️
* 🐛 Fixed parameter reflection in `Client#execute_tool` to handle zero-arity tool `call` methods without throwing `ArgumentError`.

## [0.1.0] - 2026-08-10 🚀
* 💎 Initial scaffolding for the **Ruby Antigravity SDK** (`antigravity-sdk`).
