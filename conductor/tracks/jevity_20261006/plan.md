# Implementation Plan: Jevity (`bin/jevity`) — JEV-Powered Harness

## Phase 1: JEV Client & Primitives (TDD)
- [ ] Task: Write failing RSpec unit tests for `Antigravity::Jev::Client`
  - [ ] Test API key resolution (from `ENV['JEV_API_KEY']`, `ENV['TYPESAFE_API_KEY']`, and fallback checking `$GIC/.env`)
  - [ ] Test request payload formatting for `choice`, `score`, and `noul` primitives
  - [ ] Test latency measurement recording in milliseconds
  - [ ] Test mock/stub offline mode and error handling
- [ ] Task: Implement `Antigravity::Jev::Client`
  - [ ] Implement key discovery without modifying any `.env`
  - [ ] Implement HTTP POST to `https://api.typesafe.ai/v1/systemone` using standard Net::HTTP
  - [ ] Implement response parsing for `answers` map and token usage
  - [ ] Ensure all Phase 1 tests pass
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Visual Telemetry & Model Router (TDD)
- [ ] Task: Write failing RSpec unit tests for `Antigravity::Jev::Telemetry` and `Antigravity::Jev::Router`
  - [ ] Test single-line telemetry formatting with emojis and latency badges
  - [ ] Test prompt complexity evaluation with JEV
  - [ ] Test dynamic model assignment (simple -> Flash, complex -> Pro)
- [ ] Task: Implement `Antigravity::Jev::Telemetry` and `Antigravity::Jev::Router`
  - [ ] Build colorful single-line logger (`⚡ [Jev: Xms | ...]`)
  - [ ] Implement routing logic integrating with Antigravity Gemini client
  - [ ] Ensure all Phase 2 tests pass
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Command Safety Guardrail (TDD)
- [ ] Task: Write failing RSpec unit tests for `Antigravity::Jev::Guardrail`
  - [ ] Test probability threshold classification ($\ge 0.80$ -> `:allow`, $< 0.40$ -> `:deny`, $0.40..0.80$ -> `:ask`)
  - [ ] Test simulated execution for commands (`ls`, `cat .env`, `rm -rf /`)
  - [ ] Test interactive confirmation hook for ambiguous commands
- [ ] Task: Implement `Antigravity::Jev::Guardrail`
  - [ ] Build guardrail evaluation engine using JEV `noul` primitive
  - [ ] Implement execution dispatcher respecting safety verdict
  - [ ] Ensure all Phase 3 tests pass
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: CLI Executable `bin/jevity` & Integration
- [ ] Task: Write tests / CLI specs for `bin/jevity`
  - [ ] Test `bin/jevity ask` argument parsing and execution
  - [ ] Test `bin/jevity exec` and `bin/jevity guard` flags
  - [ ] Test exit codes (0 for success/allowed, 1 for blocked/error)
- [ ] Task: Implement `bin/jevity`
  - [ ] Implement CLI binary in `bin/jevity` with shebang and executable permissions
  - [ ] Add subcommands: `ask`, `exec`, `guard`, and `interactive` mini-console
  - [ ] Wire up SDK modules, telemetry, and banner
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 5: Quality Gates & Polish
- [ ] Task: Verification & Compliance
  - [ ] Run full test suite via `just test`
  - [ ] Run Rubocop and resolve any code style issues
  - [ ] Test live run with actual `JEV_API_KEY` from `$GIC/.env`
- [ ] Task: Documentation & Release
  - [ ] Update `CHANGELOG.md` and `VERSION`
  - [ ] Phase Verification & Checkpoint (Refer to workflow.md)
