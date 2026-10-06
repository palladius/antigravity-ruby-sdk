# Specification: Jevity (`bin/jevity`) — JEV-Powered Decision & Guardrail Harness

## 1. Overview
`jevity` (a playful portmanteau of JEV and Gravity, with future room for *long-jevity* 🦖) is a mini-harness executable and SDK module that integrates **TypeSafe AI's Jev** "System One" decision model with the **Antigravity Ruby SDK**. 

It adds two primary capabilities with high-speed visual feedback:
1. **Dynamic Model Routing**: Intelligently selects between Gemini Flash (lightweight/fast) and Gemini Pro (complex reasoning) based on prompt complexity evaluated by JEV.
2. **Command Safety Guardrails**: Evaluates shell commands before execution using probabilistic safety scoring (`safe > 0.80` -> auto-execute, `safe < 0.40` -> block, `0.40..0.80` -> interactive confirmation `ask_user()`).
3. **Ultra-Fast Visual Feedback Loop**: Celebrates JEV's sub-second latency with colorful, single-line telemetry output (e.g., `⚡ [Jev: 82ms | Safe: 98.4%] ✅ Auto-approved: ls -la`).

---

## 2. Functional Requirements

### 2.1 JEV API Client (`Antigravity::Jev::Client`)
- Communicates with TypeSafe AI's System One endpoint (`https://api.typesafe.ai/v1/systemone`).
- Measures and records request roundtrip latency (in milliseconds).
- Supports core Jev primitives:
  - `choice`: categorical selection (e.g. routing between models).
  - `noul`: probabilistic true/false judgment (e.g. command safety probability).
  - `score`: rubric-based numerical grading (e.g. complexity rating 1-10).
- Authentication:
  - Resolves API key from `ENV['JEV_API_KEY']` or `ENV['TYPESAFE_API_KEY']`.
  - Fallback: inspects `$GIC/.env` or project `.env` if key is not yet exported in environment (without writing/modifying any `.env`).
  - Offline mock/stub mode for testing without requiring a live key.

### 2.2 Model Routing (`Antigravity::Jev::Router`)
- Analyzes incoming user prompt/task.
- Asks JEV to classify prompt complexity (`simple` vs `complex`).
- Telemetry: prints fast routing decision line:
  `⚡ [Jev: 94ms | Complexity: Simple (96%)] 🚀 Routed to gemini-2.5-flash`
- Dispatches prompt to Gemini using existing `Antigravity` client / harness.

### 2.3 Command Guardrail (`Antigravity::Jev::Guardrail`)
- Evaluates proposed shell commands for execution safety using `noul` primitive.
- Safety thresholds:
  - **Safe** ($\ge 0.80$): Allowed automatically (`:allow`).
  - **Dangerous** ($< 0.40$): Blocked immediately with safety rationale (`:deny`).
  - **Ambiguous** ($0.40 \le p < 0.80$): Prompts user for interactive confirmation (`:ask`).
- Fast single-line telemetry output:
  - `⚡ [Jev: 75ms | Safe: 99.2%] ✅ Auto-approved: ls -la`
  - `⚡ [Jev: 88ms | Safe: 52.4%] ⚠️ Guardrail check: cat .env -> Requires user confirmation [y/N]?`
  - `⚡ [Jev: 64ms | Safe: 1.1%] 🚫 Blocked dangerous command: rm -rf /`

### 2.4 CLI Binary (`bin/jevity`)
- Subcommands & modes:
  - `bin/jevity ask "<prompt>"`: Routes to Flash/Pro with telemetry and queries Gemini.
  - `bin/jevity exec "<command>"`: Evaluates command safety via JEV with telemetry and conditionally runs it.
  - `bin/jevity guard "<command>"`: Check only mode (returns exit code 0/1/2 and Jev decision).
  - `bin/jevity interactive`: Interactive prompt demonstrating real-time model routing and guarded execution.

---

## 3. Non-Functional Requirements & Design Principles
- **TDD Mandatory**: 100% test coverage using RSpec. Webmock/stubs for fast offline testing; live integration specs gated by `ENV['JEV_API_KEY']`.
- **Zero Destructive Actions**: Never touches or modifies `.env` files.
- **Emoji-Rich & Colorful Terminal**: Standard ANSI or colorized terminal output with Antigravity emojis (`🛰️`, `⚡`, `🛡️`, `🚦`, `🤖`).
- **Code Style**: Ruby 3.4+ style, `# frozen_string_literal: true`, namespaced under `Antigravity::Jev`.

---

## 4. Acceptance Criteria
- [ ] `Antigravity::Jev::Client` successfully queries `/v1/systemone` and reports execution latency in milliseconds.
- [ ] Visual telemetry displays fast colorful single-line feedback for decisions.
- [ ] Model router correctly steers simple prompts to Flash and complex prompts to Pro.
- [ ] Safety guardrail correctly handles thresholds (`ls` allowed, `cat .env` prompts user, `rm -rf` blocked).
- [ ] `bin/jevity` executable provides `ask`, `exec`, `guard`, and interactive commands.
- [ ] `just test` passes completely with Rubocop compliance.

---

## 5. Out of Scope
- Full web UI (CLI only).
- Background daemons.
