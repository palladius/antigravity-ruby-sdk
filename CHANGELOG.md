# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.1.9] - 2026-08-11 🎨
* 🎨 Added central `Antigravity::EMOJIS` registry (`lib/antigravity/emojis.rb`) and `Antigravity.emoji(:key)`.
* 💎 Added `.emoji` class and instance methods on core classes (`Antigravity::Agent.emoji`, `Antigravity::Tool.emoji`, `Antigravity::Sidecar::Base.emoji`, `Antigravity::Skill.emoji`, `Antigravity::Message#emoji`).
* 🚗 Updated Sidecar emoji to car (`🚗`).

## [0.1.8] - 2026-08-11 🎨
* 🎨 Added emojiful log line prefixes to `Antigravity::Guards::AgentLogger`.

## [0.1.7] - 2026-08-11 🧪
* 🧪 Added comprehensive RSpec unit tests covering all automagic logging behaviors.

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
