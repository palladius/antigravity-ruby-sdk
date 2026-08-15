# AGENTS.md 

## Coding

* Whenever you find a bug, or whenver user adds a requirements, start with a plan.
* Then add failing tests which reflect the delta between your previous and current understanding of user intent / bug.
* Then start fixing tests until the work - if you get stuck ask for help to user.

## 💎 Ruby Style

* **Terse DSL**: Use `class MyTool < Antigravity::Tool` and `name :tool_name, desc: "..."`.
* **Header**: Always include `# frozen_string_literal: true`.
* **Quotes**: Use straight quotes (`'`/`"`).

## Principles

* *DRY*. Keep things non repeated.
* *POLA*. Principle of Least Astonishment. If something hands as its indexing a whole directory, be polite and add a `puts` with whats happening. use hourglass emojis when long waits are expected.

## 🎨 Emoji Mapping

Antigravity overall: "🛰️"

* 💬 `[Antigravity::Prompt]` User prompt
* 🤖 `[Antigravity::Response]` Assistant turn
* 🛠️ `[Antigravity::Tool]` Tool execution
* 📦 `[Antigravity::Tool]` Tool result
* ❌ `[Antigravity::Tool]` Tool blocked
* 🚗 `[Antigravity::Sidecar]` Sidecar event
* 🪵 `[Antigravity::Logger]` Log notice
* 🤔 `[Thinking]` Reasoning delta

## 🛡️ Safety & Workflow

* **`.env` Protection**: Never edit or commit `.env` files.
* **Testing**: Run `just test` before submitting changes.
* **Documentation Sync**: When adding or updating SDK functionality, always ensure `docs/USER_GUIDE.md` and `skills/using-antigravity-ruby-sdk/SKILL.md` are updated accordingly.
* **Release**: Update `VERSION` / `CHANGELOG.md`, then run `just release`.
