# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.1.7] - 2026-08-11 🧪
* 🧪 Added comprehensive RSpec unit tests covering all automagic logging behaviors: `Rails.logger` auto-attachment, `ANTIGRAVITY_LOGGER` env var suppression (`false`, `0`, `none`, `no`), `RAILS_ENV` / `RACK_ENV` log path resolution, and startup notice printing.

## [0.1.6] - 2026-08-11 🔑
* 🔑 Added automatic `dotenv/load` requiring if `.env` file exists and `dotenv` gem is present.

## [0.1.5] - 2026-08-11 🪵✨
* 🪄 Added automagic Rails & ENV-aware logger initialization (Closes #2).

## [0.1.4] - 2026-08-11 🪵
* 🪵 Added `Antigravity::Guards::AgentLogger` and `Agent#attach_logger("log/antigravity.log")`.

## [0.1.3] - 2026-08-11 🛡️
* 🛡️ Added `Antigravity::Guards::FileProtection` and `Antigravity::Guards::SecretMasker`.

## [0.1.2] - 2026-08-11 🧹
* 🎨 Refactored core gem to be 100% clean and un-opinionated.

## [0.1.1] - 2026-08-11 🛠️
* 🐛 Fixed parameter reflection for zero-arity tool methods.

## [0.1.0] - 2026-08-10 🚀
* 💎 Initial scaffolding for the **Ruby Antigravity SDK** (`antigravity-sdk`).
