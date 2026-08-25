# Implementation Plan: Riccardo Policy DSL & Gemini Config Importer

## Phase 1: Policy Extension & Importer Implementation
- [x] Task: Create `lib/antigravity/policy/riccardo.rb` defining `Policy.riccardo` preset.
- [x] Task: Add `Policy.from_gemini_config` importer and `Policy#to_ruby_dsl` exporter to `lib/antigravity/policy.rb`.
- [x] Task: Register `:riccardo` preset in `Policy.preset(:riccardo)`.
- [x] Task: Update `docs/USER_GUIDE.md` and `skills/using-antigravity-ruby-sdk/SKILL.md`.
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Testing & Verification
- [x] Task: Write RSpec unit test `spec/antigravity/riccardo_policy_spec.rb`.
- [x] Task: Run `just test` to verify zero test failures.
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)
