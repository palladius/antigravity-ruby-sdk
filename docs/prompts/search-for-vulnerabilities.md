# Prompt: Search for Vulnerabilities & Code Quality Findings

Use this prompt for periodic security audits and code quality reviews of the Ruby codebase.

---

## 🤖 Prompt

```markdown
Use the `code-quality-review` and `security-audit` skills to perform a thorough code review of the Ruby source files in `lib/`.

Focus on:
1. Secrets Hygiene (no hardcoded keys or uncommitted `.env` files).
2. Process & Command Safety (avoid shell interpolation in `Open3` or `system` calls).
3. Type Safety & Error Handling (safe `YAML.safe_load`, `Gem::Version.correct?`, proper rescue blocks).
4. Secure Tempfile Creation (use `Dir.mktmpdir` or `Tempfile`, never hardcoded `/tmp/` paths).
5. Network & Timeout Hygiene (explicit timeouts on WebSocket and HTTP requests).

Format your output with severity emojis:
- 🚨 CRITICAL
- 🔴 HIGH
- 🟡 MEDIUM
- 🔵 LOW
- ✅ PASSED

Summarize findings in a markdown table and highlight the top 3 actionable items to fix.
```

---

## ⏰ Recurring Maintenance (`/schedule` or Cron)

You can run this prompt on demand or schedule it weekly in your agent environment:

```bash
# Example /schedule command for weekly security audit
/schedule CronExpression="0 9 * * 1" Prompt="Run docs/prompts/search-for-vulnerabilities.md on lib/"
```
