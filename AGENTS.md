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

## 🔄 Maintenance Prompts & Workflow Shortcuts

When requested to perform maintenance audits, run the corresponding prompt file:

* ☀️ **Daily AI Job**: Read and execute [`docs/prompts/daily-ai-job.md`](file:///Users/ricc/.gemini/antigravity/worktrees/antigravity-ruby-sdk/fix_ruby_security_findings/docs/prompts/daily-ai-job.md) (or `just daily-ai-job`).
* 🛡️ **Vulnerability Audit**: Read and execute [`docs/prompts/search-for-vulnerabilities.md`](file:///Users/ricc/.gemini/antigravity/worktrees/antigravity-ruby-sdk/fix_ruby_security_findings/docs/prompts/search-for-vulnerabilities.md).
* 🔄 **Docs Sync Check**: Read and execute [`docs/prompts/verify-functionality-and-docs-in-sync.md`](file:///Users/ricc/.gemini/antigravity/worktrees/antigravity-ruby-sdk/fix_ruby_security_findings/docs/prompts/verify-functionality-and-docs-in-sync.md).
* 💎 **Ruby Elegance Audit**: Read and execute [`docs/prompts/assert-ruby-elegance-and-beauty-are-preserved.md`](file:///Users/ricc/.gemini/antigravity/worktrees/antigravity-ruby-sdk/fix_ruby_security_findings/docs/prompts/assert-ruby-elegance-and-beauty-are-preserved.md).
