# Implementation Plan: Add Antigravity Ruby SDK Agent Skill & Maintain Docs Rule

## Phase 1: Skill Definition & Documentation Sync Rules
- [ ] Task: Create `skills/using-antigravity-ruby-sdk/SKILL.md` with complete usage instructions, architecture notes, and links to `docs/USER_GUIDE.md`.
- [ ] Task: Patch `AGENTS.md` to add documentation and skill maintenance rules.
- [ ] Task: Update `README.md` to document `npx skills add` usage for installing SDK skills.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Testing & Verification
- [ ] Task: Add RSpec unit test verifying `Antigravity::Skill.load('skills/using-antigravity-ruby-sdk')`.
- [ ] Task: Test `npx skills` command integration.
- [ ] Task: Run `just test` to verify zero test failures.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
