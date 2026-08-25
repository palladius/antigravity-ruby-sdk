# Prompt: Assert Ruby Elegance and Beauty Are Preserved 💎

Use this prompt to audit the codebase for idiomatic Ruby style, developer happiness, terse DSL design, and zero bloat.

---

## 🤖 Prompt

```markdown
Review the Ruby code in `lib/` and `examples/` to assert that Ruby elegance, beauty, and developer happiness are preserved.

Check against these core principles:
1. **Beautiful Ruby DSL**:
   - Prefer symbols over strings for static keys (`name: :tool_name`, `policy: :cautious`, `model: :flash`).
   - Code should read naturally and expressively, like a clean Rails model file.
2. **Minimalism & Trimming ("Limare")**:
   - Evaluate every DSL method and spec: *"Can we trim ('limare') anything out of this while keeping it clear?"*
   - Fewer words in specs and APIs mean a cleaner, more beautiful codebase.
3. **Principle of Least Astonishment (POLA)**:
   - Methods should do what the caller intuitively expects without surprising side effects.
   - If an operation takes time (e.g. workspace indexing), print a friendly status notice with hourglass emojis.
4. **Terse DSL Patterns**:
   - Use `class MyTool < Antigravity::Tool` and `name :tool_name, desc: "..."`.
   - Always include `# frozen_string_literal: true` at the top of every Ruby source file.
5. **Zero Bloat**:
   - Keep stdlib dependencies lean; do not add heavy external gems when hand-rolled stdlib code is clean and reliable.

List any areas where code can be trimmed or made more elegant, providing before/after diff refactoring suggestions.
```

---

## ⏰ Recurring Maintenance (`/schedule` or Cron)

Run this prompt periodically to keep code quality and aesthetic standards high:

```bash
# Example /schedule command for weekly elegance check
/schedule CronExpression="0 10 * * 5" Prompt="Run docs/prompts/assert-ruby-elegance-and-beauty-are-preserved.md"
```
