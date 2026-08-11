# 📝 Changelog — `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [0.4.0] - 2026-08-11 📚🚀

### Agent Skills (GHI #11)
* 📚 Full Agent Skills support with progressive disclosure API.
* 🏗️ Constructor: `Agent.new(skills: [local_path, github_url])` — mix local and remote freely.
* ➕ Runtime: `add_skill(path, skill_name:)`, `add_skills([...])`, `add_inline_skill(name:, description:, instructions:)`.
* 🔍 Smart `SkillResolver` — auto-discovers `SKILL.md`, `skills/` subfolders, or flat containers.
* 🐙 GitHub auto-clone: `add_skill("https://github.com/org/repo")` clones to `~/.antigravity/cache/ruby-sdk/skills/`.
* 🔌 Harness wiring: skills paths sent as `skillsPaths` in `InitializeConversationEvent`.
* 🧪 76 specs passing (was 29 in 0.3.0).

### Workspace & Streaming
* 📂 Workspace analysis with `workspace:` parameter — harness indexes the directory.
* 🛠️ Harness-side built-in tools enabled by default (list_dir, view_file, grep_search, etc.).
* 🎨 Cyan-colored streaming output with separator lines in examples.
* ⏱️ Per-message idle timeout (not total deadline) for long agentic runs.

### Logging
* 🪵 Dual-output `AgentLogger`: fat JSONL (`log/antigravity.jsonl`) + compact one-liners (`.log`).
* 📊 Structured telemetry with request/response sizes in bytes.

### Examples
* 🗣️ `04_simple_llm_chat.rb` — minimal chat, no workspace.
* 🔍 `05_workspace_analysis.rb` — indexes a directory, asks about it.
* 🛡️ `06_skill_security_audit.rb` — local skill + inline skill, code quality review.
* 🐙 `07_skill_sre_postmortem.rb` — loads SRE skills from GitHub, drafts a post-mortem.

### Bundled Skills
* 🛡️ `skills/code-quality-review/` — Ruby codebase review checklist.
* 🔐 `skills/security-audit/` — Security-focused code review.


## [0.3.0] - 2026-08-11 🏗️🤷
* 🏗️ Introduced `Antigravity::Base` superclass — all SDK classes (`Agent`, `Tool`, `Skill`, `Message`, `Sidecar::Runner`) now inherit from it.
* 🪄 Automagic emoji via `inherited` hook: any `< Base` subclass gets `.emoji` / `#emoji` for free. Unknown classes default to 🤷.
* 🚗 Renamed `Sidecar::Base` → `Sidecar::Runner` (backward-compat alias preserved).
* 🧹 Removed all manual `include Emojifiable` boilerplate from domain classes.
* 🧪 29 specs passing.

## [0.2.0] - 2026-08-11 💎✨
* 🪄 Created polymorphic `Antigravity::Emojifiable` mixin and reflection method `Antigravity.emoji_for(target)`.
* 🧹 Eliminated duplicated `.emoji` method boilerplate across `Agent`, `Tool`, `Sidecar::Base`, `Skill`, and `Message` by using single mixin inclusion (`include Antigravity::Emojifiable`).

## [0.1.9] - 2026-08-11 🎨
* 🎨 Added central `Antigravity::EMOJIS` registry (`lib/antigravity/emojis.rb`) and `Antigravity.emoji(:key)`.

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
