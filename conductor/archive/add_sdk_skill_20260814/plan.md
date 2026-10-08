# Implementation Plan: Add Antigravity Ruby SDK Agent Skill & Maintain Docs Rule

## Phase 1: Skill Definition & Documentation Sync Rules
- [x] Task: Create `skills/using-antigravity-ruby-sdk/SKILL.md` with complete usage instructions, architecture notes, and links to `docs/USER_GUIDE.md`.
- [x] Task: Patch `AGENTS.md` to add documentation and skill maintenance rules.
- [x] Task: Update `README.md` to document `npx skills add` usage for installing SDK skills.
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Testing & Verification
- [x] Task: Add RSpec unit test verifying `Antigravity::Skill.load('skills/using-antigravity-ruby-sdk')`.
- [x] Task: Test `npx skills` command integration.
- [x] Task: Run `just test` to verify zero test failures.
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)
