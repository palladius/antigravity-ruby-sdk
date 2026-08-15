# Specification: Add Antigravity Ruby SDK Agent Skill & Maintain Docs Rule

## Overview
Create an official agent skill at `skills/using-antigravity-ruby-sdk/SKILL.md` (inspired by Guillaume Laforge's article on building Antigravity SDKs) to instruct AI agents on how to use the Ruby SDK effectively. Update `AGENTS.md` to enforce a rule requiring developers and agents to maintain `docs/USER_GUIDE.md` and `skills/using-antigravity-ruby-sdk/SKILL.md` whenever new functionality is added or updated. Also document `npx skills add` usage in `README.md` and test skill compatibility.

## Functional Requirements
1. **Skill Definition (`skills/using-antigravity-ruby-sdk/SKILL.md`)**:
   - Standard YAML frontmatter (`name: using-antigravity-ruby-sdk`, `description`).
   - Comprehensive usage guide (Initialization, localharness architecture, `Tool.define`, streaming, skills, policies, hooks).
   - Links to `docs/USER_GUIDE.md`.
2. **Repository Rule Patch (`AGENTS.md`)**:
   - Add explicit rule: "When adding or updating SDK functionality, always update `docs/USER_GUIDE.md` and `skills/using-antigravity-ruby-sdk/SKILL.md` accordingly."
3. **CLI Skill Installation (`README.md`)**:
   - Document how to install/use `using-antigravity-ruby-sdk` via `npx skills add ...`.
4. **Testing & Verification**:
   - Add unit test verifying `Antigravity::Skill.load` loads `skills/using-antigravity-ruby-sdk`.
   - Test `npx skills` command compatibility.

## Non-Functional Requirements
- Follow Agentskills.io specification format.
- Ensure all tests pass (`just test`).

## Acceptance Criteria
- `skills/using-antigravity-ruby-sdk/SKILL.md` exists and passes unit tests.
- `AGENTS.md` and `README.md` are updated.
- `just test` passes with 0 failures.
