# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.1.5] - 2026-08-11 🪵✨
* 🪄 Added automagic Rails & ENV-aware logger initialization (Closes #2):
  1. Auto-attaches `Rails.logger` if defined.
  2. Auto-attaches standard file logger unless `ENV['ANTIGRAVITY_LOGGER']` is `false`.
  3. Resolves log target to `log/#{ENV['RAILS_ENV']}.log` when `RAILS_ENV` / `RACK_ENV` is set, defaulting to `log/antigravity.log`.
  4. Outputs `🪵 Logging to [TARGET]` on agent initialization.
  5. Auto-creates `log/` directory via `FileUtils.mkdir_p`.

## [0.1.4] - 2026-08-11 🪵
* 🪵 Added `Antigravity::Guards::AgentLogger` and `Agent#attach_logger("log/antigravity.log")` for logging prompts, responses, and tool calls to standard Ruby/Rails log targets.

## [0.1.3] - 2026-08-11 🛡️
* 🛡️ Added `Antigravity::Guards::FileProtection` (`files: [".env", "Gemfile"]`) and `Antigravity::Guards::SecretMasker` as clean, opt-in helper classes in `lib/antigravity/guards.rb`.

## [0.1.2] - 2026-08-11 🧹
* 🎨 Refactored core gem to be 100% clean and un-opinionated by removing hardcoded safety defaults from `Agent.new`.

## [0.1.1] - 2026-08-11 🛠️
* 🐛 Fixed parameter reflection in `Client#execute_tool` to handle zero-arity tool `call` methods without throwing `ArgumentError`.

## [0.1.0] - 2026-08-10 🚀
* 💎 Initial scaffolding for the **Ruby Antigravity SDK** (`antigravity-sdk`).
