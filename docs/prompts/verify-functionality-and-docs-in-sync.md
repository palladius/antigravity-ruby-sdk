# Prompt: Verify Functionality and Documentation Synchronization

Use this prompt to ensure codebase features, user guides, skills, and README stay 100% in sync after adding or modifying functionality.

---

## 🤖 Prompt

```markdown
Audit the latest code changes in `lib/` against our primary documentation files:
- `docs/USER_GUIDE.md`
- `skills/using-antigravity-ruby-sdk/SKILL.md`
- `README.md`
- `AGENTS.md`

Check that:
1. Every public API feature or configuration option added in `lib/antigravity/` is documented in `docs/USER_GUIDE.md`.
2. The agent skill `skills/using-antigravity-ruby-sdk/SKILL.md` includes examples for any new agent DSL methods or tools.
3. `README.md` code snippets reflect the current recommended syntax.
4. Any new safety rules or workflow protocols are reflected in `AGENTS.md`.

Report any discrepancies as a diff or markdown checklist with recommended updates for each missing documentation item.
```

---

## ⏰ Recurring Maintenance (`/schedule` or Cron)

Run this prompt after completing features or on PR reviews:

```bash
# Example /schedule command for daily docs sync check
/schedule CronExpression="0 17 * * 1-5" Prompt="Run docs/prompts/verify-functionality-and-docs-in-sync.md"
```
