# 📝 Changelog -- `antigravity-sdk`

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.5.4] - 2026-08-14 📂 Workspace Indexing Hooks
### Features
* 📂 **Indexing lifecycle hooks**: New `:indexing_start` and `:indexing_done` hooks emitted around `initialize_session!` when a workspace is configured. Zero concurrency risk — just timing wrappers.
* 🪝 **Lifecycle logger**: Prints `🪝 📂 indexing | /path/` and `🪝 ✅ indexed | /path/ | 0.03s` so you always know when indexing starts and finishes.

## [0.5.3] - 2026-08-14
### Bug Fixes
* 🐛 **GHI #24 — FULLY_IDLE race condition**: Fixed 0B responses on fast turns. Three-part fix:
  1. `usageUpdate` no longer sets `seen_any_step` (it leaked across turns, tricking the stale guard)
  2. Removed `elapsed` time fallback — only `stepUpdate`/`toolCall` gates FULLY_IDLE acceptance
  3. Adaptive drain: 3s when FULLY_IDLE arrives without text (was 0.5s, too short for thinking turns)
* 🧪 **conversation_spec.rb**: 12 unit tests covering FULLY_IDLE drain, stale rejection, usage capture, tool counting
* 🐛 **Telegram Bot**: Fixed an issue where the `/stop` command would shut down the bot instantly without acknowledging the message offset, leading to infinite restart loops.
* 🛡️ **Tool Policies**: Fixed an issue where `run_pre_tool` and `run_post_tool` hooks were bypassed during `conversation.rb` execution, which broke safety guards and `AgentLogger` tool logging.

## [0.5.2] - 2026-08-14 🪝🌍 Lifecycle Hooks + Tool Emissions (GHI #22, #24)

### Features
* 🪝 **Lifecycle Logger**: All hook output prefixed with 🪝, `\n` before `session_start`/`post_turn` for clean separation.
* 🔧 **Tool Hook Emissions**: `conversation.rb` now emits `:tool_call`, `:tool_result`, `:tool_error` hooks — previously wired but never fired!
* 🪙 **Token display**: Fixed key path bug (`dig(:tokens,:total)` → `[:total_tokens]`), added 🪙 emoji, `B` (bytes) instead of `ch`.
* ⏱️ **Agent uptime**: `agent.born_at`, `agent.uptime`, `agent.uptime_human` ("7.3s", "1m 23.4s").
* 📦 **dotenv as runtime dep**: Added to gemspec + `rv_init.rb`, `.env` now auto-loaded. Env checks use `.strip` for trailing spaces.
* 🌍 **whereami example**: 4-turn E2E demo — geolocation tool (ipinfo.io JSON), flag emoji follow-up, Ruby love, Python vs Ruby.
* 📦 **gem.coop registry**: Configured `just release` to double-publish to RubyGems and the new gem.coop alternative registry!
  * Custom post-tool hook parses JSON and prints `📍 IP (City, Country)`.
  * Proper status envelope `{status: "success", response: data}` with error handling.

### Bug Fixes
* 🐛 Token count always showed 0 in lifecycle logger (wrong key path).
* 🐛 Filed GHI #24: `usageUpdate` race condition when `FULLY_IDLE` arrives first.

### Tests
* 🧪 23 new specs for `LifecycleLogger` + `Colors` (status_line, all hook events, verbose mode, ANSI/TTY safety).

## [0.5.1] - 2026-08-14 📜 Add LICENSE

### Features
* 📜 **License**: Added Apache 2.0 LICENSE file to match the Python SDK.

## [0.5.0] - 2026-08-14 🔒 Declarative Policy DSL (GHI #21)

### Features
* 🛡️ **Declarative Policy DSL**: `Antigravity::Policy` — Rails-like DSL for agent tool-access control.
  * `allow`, `deny`, `confirm` rules with predicate helpers: `cmd()`, `path()`, `args_match()`.
  * **Order does NOT matter** — rules resolved by precedence, not insertion order.
  * Agent sugar: `Agent.new(policy: :default)` or `Agent.new(policy: my_policy)`.
* 📋 **5 built-in presets**: `:cautious`, `:default`, `:turbo`, `:test`, `:auto`.
  * `:auto` reads `ANTIGRAVITY_ENV` → `RAILS_ENV` → `RACK_ENV` to pick the right preset.
* 📂 **Sandbox directories**: `scratch/` and `out/` always writable, even in `:cautious` / production.
* 🔥 **Destructive git protection**: `git reset --hard`, `git push --force`, `git clean -fdx`, `git stash drop` — confirmed or denied depending on preset.
* 🕵️ **File-reader bypass prevention**: `cat`, `head`, `tail`, `strings` separated into `READ_CMDS` — blocked in `:cautious` to prevent `view_file` deny bypass.

### Refactor
* Extracted all curated command/file/tool lists into `lib/antigravity/policy/constants.rb` — one entry per line for easy PR review.

### Docs
* README: full Policy DSL section with preset table, sandbox docs, `RAILS_ENV` mapping, and order-independence explanation.
* `policy.rb`: prominent docblock explaining declarative precedence model.

### Tests
* 53 unit tests (order independence, presets, predicates, sandbox dirs).
* 34 e2e assertions in `examples/11_e2e_policy_assertions.rb` (custom policy + prod sandbox).

## [0.4.4] - 2026-08-14 🪝🌈

### Lifecycle Hooks & Observability (GHI #22)
* 🪝 **Session lifecycle hooks**: `on(:session_start)` and `on(:session_end)` events emitted from `connect!`/`close!` with model, conversation_id, turn_count metadata.
* 🌈 **`Antigravity::Colors`**: lightweight ANSI color module (no deps, TTY-safe). Used internally and available for examples.
* 📊 **`Antigravity::LifecycleLogger`**: auto-attachable colorful logger that prints compact status lines on every hook event -- inspired by Cloud Code's status bar.
  * `ANTIGRAVITY_LIFECYCLE=1` to enable, or auto-enabled when `RAILS_ENV=test` or `RAILS_ENV=development`.
  * `ANTIGRAVITY_LIFECYCLE_VERBOSE=1` for response content previews.
  * Prints: `🟢 session_start | model=... | conv=...`, `➡️ pre_turn T1 | "prompt..."`, `⬅️ post_turn T1 | 42ch 1L | 0.8s`, `🔴 session_end | 3 turns | 1.2k tok | 4.5s`.

### Feature Parity Tracking (GHI #20)
* 📊 Added [`docs/FEATURE_PARITY.md`](docs/FEATURE_PARITY.md) -- 85-feature matrix comparing Ruby vs Python SDK (~35% parity, 10 Ruby-unique features).
* 📊 Added compact parity status table to README.
* 🛡️ Filed GHI #21 (Declarative Policy Engine) and GHI #22 (Lifecycle Hooks) as sub-issues of epic #20.

## [0.4.3] - 2026-08-13 🎤🐛

### Bug Fix: Voice Messages Return Empty (GHI #18)
* 🐛 **Root cause**: stale `FULLY_IDLE` in WebSocket buffer. During voice transcription (5-10s HTTP call to Gemini API), a leftover `FULLY_IDLE` from the previous turn sits unread. `collect_response` picks it up and exits immediately with zero steps/text.
* 🧹 **`drain_stale_messages`**: non-blocking flush of leftover WS messages before sending `userInput` event. Belt-and-suspenders defense.
* 🛡️ **FULLY_IDLE guard**: ignore `FULLY_IDLE` that arrives with zero `stepUpdate`/`toolCall`/`usageUpdate` AND within 1s of turn start -- it's definitely stale.
* 🔍 Debug hooks emit `_debug: 'drained_stale_message'` and `'skipped_stale_fully_idle'` for observability.

### Telegram Bot Improvements
* 🎤 Markdown escaping for transcription display (prevents Telegram API errors on special chars).
* 🔧 `response.content` fallback when streaming chunks are empty.
* 🐛 Debug logging (`tool_calls`, `thinking`, `steps`) on empty responses.

### Docs & README
* 🏛️ Added [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) with plan-vs-reality comparison and nanobanana E2E flow diagram.
* 🖼️ Generated architecture diagram: [`docs/images/architecture_nanobanana.jpg`](docs/images/architecture_nanobanana.jpg).
* 📝 README: gem badge, RubyGems link, Related Projects table (official Python SDK, Java SDK).

## [0.4.2] - 2026-08-13 🍌🎉

### E2E Nano Banana Pipeline (9/9 green!)
* 🍌 `examples/09_e2e_nanobanana.rb` -- full end-to-end test: find skill -> load skill -> generate image -> verify output.
* 🚫 **No session restart.** Phases 3-4 now run in the SAME session (no `close!` + reconnect). Eliminates context amnesia (GHI #16).
* 🔧 **Truncated `load_skill` tool result.** Was returning 61-line SKILL.md content, causing model to hang 20s+ thinking. Now returns 4-line summary: name, script path, description, usage hint.
* 🛡️ **Failsafe command building.** If model times out building the `uv run` command, harness constructs it directly from `scripts/generate_image.py` path + known parameters.
* ⏱️ Phase 3 wrapped in `rescue` -- timeout no longer crashes the entire test.
* 🖼️ Image generation: 17-19s, ~1MB PNG, auto-opened on Mac via `open`.

### Learnings
* 💡 **Tool Result Hygiene**: Large tool responses (>10 lines) cause model thinking hangs. Keep tool results concise -- return summaries, not full file contents.
* 💡 **Graceful degradation**: assert-after-fallback pattern lets tests verify end state, not intermediate steps.

## [0.4.1] - 2026-08-12 🎣🔧

### Generic Event Hooks
* 🎣 `hooks.on(:event) { |data| ... }` / `hooks.emit(:event, data)` — subscribe to any named event.
* 📡 `:ws_message` event emitted for every WebSocket message in `collect_response`.
* 🔍 Enables debug tracing from tests/bots WITHOUT touching `conversation.rb`:
  ```ruby
  agent.hooks.on(:ws_message) { |msg| $stderr.puts msg.keys }
  ```

### E2E Test Fixes
* 🧪 Fixed Phase 4 empty response — model was brute-forcing filesystem `find` commands instead of reading loaded skill.
* 📝 System instruction now explicitly forbids filesystem tools when answering from loaded skills.
* 🔄 Retry with session reset (up to 3 attempts) for model timeout/flakiness after session restart.
* 🐛 Fixed `NameError: undefined local variable 'metaskill_paths'` in retry path.

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
