# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.1.2] - 2026-08-11 🧹
* 🎨 Refactored core gem to be 100% clean and un-opinionated by removing hardcoded safety defaults from `Agent.new`.
* 📚 Relocated `ProtectedFilesGuard` and `SecretMasker` into educational example recipes (`examples/03_e2e_safety_and_sidecar.rb`) to teach developers how to write custom hooks.

## [0.1.1] - 2026-08-11 🛠️
* 🐛 Fixed parameter reflection in `Client#execute_tool` to handle zero-arity tool `call` methods without throwing `ArgumentError`.

## [0.1.0] - 2026-08-10 🚀
* 💎 Initial scaffolding for the **Ruby Antigravity SDK** (`antigravity-sdk`).
* 🤖 `Antigravity::Agent` class supporting reflective block configuration and RubyLLM-inspired streaming.
* 🪝 `Antigravity::Hooks` lifecycle engine for pre-turn, post-turn, and tool execution interception.
* 🛠️ `Antigravity::Tool` base class & dynamic block tool registration.
* 🛰️ `Antigravity::Harness` localharness Go process manager.
* ⚡ `Antigravity::Client` WebSocket event routing.
* 📁 `Antigravity::Skill` standard `SKILL.md` parser and skill bundle loader.
