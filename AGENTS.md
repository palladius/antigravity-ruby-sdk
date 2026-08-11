# 🤖 AGENTS.md — Agent Guidelines

## 💎 Ruby Style
* **Terse DSL**: Use `class MyTool < Antigravity::Tool` and `name :tool_name, desc: "..."`.
* **Header**: Always include `# frozen_string_literal: true`.
* **Quotes**: Use straight quotes (`'`/`"`). Single quotes in git commit messages (`git commit -m '...'`).

## 🎨 Emoji Mapping
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
* **Release**: Update `VERSION` / `CHANGELOG.md`, then run `just release`.
