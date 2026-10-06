# Implementation Plan: Jevity (`bin/jevity`) — JEV-Powered Harness

## Phase 1: JEV Client & Primitives (TDD)
- [x] Task: Write failing RSpec unit tests for `Antigravity::Jev::Client`
  - [x] Test API key resolution (from `ENV['JEV_API_KEY']`, `ENV['TYPESAFE_API_KEY']`, and fallback checking `$GIC/.env`)
  - [x] Test request payload formatting for `choice`, `score`, and `noul` primitives
  - [x] Test latency measurement recording in milliseconds
  - [x] Test mock/stub offline mode and error handling
- [x] Task: Implement `Antigravity::Jev::Client`
  - [x] Implement key discovery without modifying any `.env`
  - [x] Implement HTTP POST to `https://api.typesafe.ai/v1/systemone` using standard Net::HTTP
  - [x] Implement response parsing for `answers` map and token usage
  - [x] Ensure all Phase 1 tests pass
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Visual Telemetry & Model Router (TDD)
- [x] Task: Write failing RSpec unit tests for `Antigravity::Jev::Telemetry` and `Antigravity::Jev::Router`
  - [x] Test single-line telemetry formatting with emojis and latency badges
  - [x] Test prompt complexity evaluation with JEV
  - [x] Test dynamic model assignment (simple -> Flash, complex -> Pro)
- [x] Task: Implement `Antigravity::Jev::Telemetry` and `Antigravity::Jev::Router`
  - [x] Build colorful single-line logger (`⚡ [Jev: Xms | ...]`)
  - [x] Implement routing logic integrating with Antigravity Gemini client
  - [x] Ensure all Phase 2 tests pass
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Command Safety Guardrail (TDD)
- [x] Task: Write failing RSpec unit tests for `Antigravity::Jev::Guardrail`
  - [x] Test probability threshold classification ($\ge 0.80$ -> `:allow`, $< 0.40$ -> `:deny`, $0.40..0.80$ -> `:ask`)
  - [x] Test simulated execution for commands (`ls`, `cat .env`, `rm -rf /`)
  - [x] Test interactive confirmation hook for ambiguous commands
- [x] Task: Implement `Antigravity::Jev::Guardrail`
  - [x] Build guardrail evaluation engine using JEV `noul` primitive
  - [x] Implement execution dispatcher respecting safety verdict
  - [x] Ensure all Phase 3 tests pass
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: CLI Executable `bin/jevity` & Integration
- [x] Task: Write tests / CLI specs for `bin/jevity`
  - [x] Test `bin/jevity ask` argument parsing and execution
  - [x] Test `bin/jevity exec` and `bin/jevity guard` flags
  - [x] Test exit codes (0 for success/allowed, 1 for blocked/error)
- [x] Task: Implement `bin/jevity`
  - [x] Implement CLI binary in `bin/jevity` with shebang and executable permissions
  - [x] Add subcommands: `ask`, `exec`, `guard`, and `interactive` mini-console
  - [x] Wire up SDK modules, telemetry, and banner
- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 5: Quality Gates & Polish
- [x] Task: Verification & Compliance
  - [x] Run full test suite via `just test`
  - [x] Run Rubocop and resolve any code style issues
  - [x] Test live run with actual `JEV_API_KEY` from `$GIC/.env`
- [x] Task: Documentation & Release
  - [x] Update `CHANGELOG.md` and `VERSION`
  - [x] Phase Verification & Checkpoint (Refer to workflow.md)
