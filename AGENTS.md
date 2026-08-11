# 🤖 AGENTS.md — Guidelines for AI Coding Assistants

Welcome to `antigravity-sdk` (Ruby Antigravity SDK). When working on this codebase, you **MUST** adhere to the following Ruby implementation, style, and emoji guidelines.

---

## 💎 1. Ruby Implementation Philosophy & Style

* **Terse & Expressive DSL**: Follow standard Ruby community conventions (modeled after `RubyLLM`).
* **Frozen String Literals**: Always place `# frozen_string_literal: true` at the very top of every `.rb` file.
* **Tool Subclassing over Mixins**: Prefer `class MyTool < Antigravity::Tool` over `include Antigravity::Tool`.
* **Concise Symbol Tool DSL**:
  ```ruby
  class WeatherTool < Antigravity::Tool
    name :get_weather, desc: "Retrieves weather report"
    param :city, type: :string, description: "City name"

    def call(city:)
      "Sunny in #{city}"
    end
  end
  ```
* **No Smart Quotes**: NEVER use curly/skewed smart quotes (like `’`, `”`). Always stick to straight UNIX-style single/double quotes (`'` and `"`).
* **Single Quotes in Git Commits**: Always use single quotes for git commits (`git commit -m '...'`) to prevent shell backtick interpolation issues.

---

## 🎨 2. Emoji Guidelines & Mapping

Emojis make agent logging, CLI output, and documentation expressive and readable.

### Log Line Emojis (`Antigravity::Guards::AgentLogger`)
When formatting structured logs, use these exact emoji prefixes:

| Event | Emoji | Example |
| :--- | :---: | :--- |
| **User Prompt** | 💬 | `💬 [Antigravity::Prompt] User: 'Hello'` |
| **Assistant Response** | 🤖 | `🤖 [Antigravity::Response] Assistant (gemini-flash-latest): ...` |
| **Tool Execution** | 🛠️ | `🛠️ [Antigravity::Tool] Executing 'get_weather'` |
| **Tool Result** | 📦 | `📦 [Antigravity::Tool] Result for 'get_weather': Sunny in Milan` |
| **Tool Blocked** | ❌ | `❌ [Antigravity::Tool] Result for 'write_file': ❌ TOOL BLOCKED` |
| **Sidecar Event** | 🚗 | `🚗 [Antigravity::Sidecar] Event :turn_completed` |
| **Logger Notice** | 🪵 | `🪵 Logging to log/antigravity.log` |

### General UI & Documentation Emojis
* 💎 — Gem / SDK core features
* 🚀 — Quickstart & releases
* 🛡️ — Security guards & safety policy
* 🏎️ / 🚗 — Sidecars & background workers
* 🤔 — Agent reasoning & thinking deltas (`🤔 [Thinking]`)
* 🧪 — RSpec unit tests (`just test`)

---

## 🛡️ 3. Security & Safety Principles

* **`.env` Protection**: NEVER modify or overwrite `.env` files. Always check `.gitignore` to ensure `.env*` is untracked.
* **Opt-In Guard Helpers**: Keep security policies configurable and opt-in (`Antigravity::Guards::FileProtection`, `Antigravity::Guards::SecretMasker`).

---

## 🧪 4. Testing & Release Workflow

1. **Task Runner**: First check `justfile` for project tasks. Run tests via `just test` (`bundle exec rake spec`).
2. **Version Bump**: Update `VERSION` and `CHANGELOG.md` for any functional updates or bug fixes.
3. **Release Pipeline**: Use `just release` (`bundle exec rake release`) to build the gem, create git tags, push commits to GitHub, and publish to RubyGems.org.
