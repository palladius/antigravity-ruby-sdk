# Prompt: The Daily AI Job ☀️

Use this master prompt to execute the complete daily maintenance and auditing workflow for the Antigravity Ruby SDK repository.

---

## 🤖 Prompt Instructions

```markdown
Execute the **Daily AI Job** checklist for this repository:

1. **Security & Code Quality Scan**:
   Run `docs/prompts/search-for-vulnerabilities.md` against `lib/`. Verify process safety, tempdir creation, and secrets hygiene.

2. **Documentation & Skills Synchronization**:
   Run `docs/prompts/verify-functionality-and-docs-in-sync.md`. Assert that `lib/antigravity/` features, `docs/USER_GUIDE.md`, `skills/using-antigravity-ruby-sdk/SKILL.md`, and `README.md` are 100% aligned.

3. **Ruby Elegance & Aesthetics Audit**:
   Run `docs/prompts/assert-ruby-elegance-and-beauty-are-preserved.md`. Check for:
   - Symbol keys for static options (`name: :tool_name`, `policy: :cautious`).
   - Expressive, Rails-model-like syntax.
   - Code trimming ("limare out unnecessary words/boilerplate").
   - Zero unnecessary dependencies.

4. **Automated Test Verification**:
   Run `just test` to verify all RSpec unit tests pass cleanly.

Provide a concise summary report with emojis (🚨, 🔴, 🟡, 🔵, ✅) and list any open action items.
```

---

## ⏰ How to Run "The Daily AI Job"

### Option A: Recurring Schedule (`/schedule`)

Schedule a daily cron notification in your Antigravity agent environment (runs Monday through Friday at 9:00 AM):

```bash
/schedule CronExpression="0 9 * * 1-5" Prompt="Execute the Daily AI Job from docs/prompts/daily-ai-job.md"
```

### Option B: On-Demand Shell Execution

Run directly via `just` or `rv`:

```bash
just daily-ai-job
```
