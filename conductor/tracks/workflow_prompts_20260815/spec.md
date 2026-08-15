# Specification: Reusable Workflow Maintenance Prompts

## Overview
Create a suite of standardized, reusable workflow prompts in `docs/prompts/` to facilitate periodic daily/weekly codebase maintenance, security auditing, documentation synchronization checks, and Ruby elegance verification. Document how developers and agents can execute these prompts on demand or on a recurring schedule.

## Functional Requirements
1. **Workflow Prompts Suite (`docs/prompts/`)**:
   - `docs/prompts/search-for-vulnerabilities.md`: Standardized prompt leveraging `code-quality-review` and `security-audit` skills for security and code quality reviews.
   - `docs/prompts/verify-functionality-and-docs-in-sync.md`: Prompt for auditing codebase alignment with `docs/USER_GUIDE.md`, `skills/using-antigravity-ruby-sdk/SKILL.md`, and `README.md`.
   - `docs/prompts/assert-ruby-elegance-and-beauty-are-preserved.md`: Prompt for auditing Ruby idiomatic style, POLA (Principle of Least Astonishment), terse DSL design, and zero bloat.
2. **User Guide & README Integration**:
   - Add a section in `docs/USER_GUIDE.md` and `README.md` explaining how to run these maintenance prompts manually or on a recurring schedule with `/schedule` or `just`.
3. **Automated Verification**:
   - Add an RSpec test verifying that all prompt files in `docs/prompts/` exist and are well-formed markdown documents.

## Non-Functional Requirements
- Follow clean Markdown structure.
- Ensure all tests pass (`just test`).

## Acceptance Criteria
- All 3 prompt files created under `docs/prompts/`.
- `USER_GUIDE.md` and `README.md` updated with workflow guidance.
- RSpec verification test passes with 0 failures.
