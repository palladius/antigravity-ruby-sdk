# Technology Stack

## Language
- **Ruby** 3.4+ (primary)
- Managed via `rv` (Ruby version manager)

## Core Dependencies
- `websocket` (~> 1.2) — WebSocket protocol for harness communication
- `dotenv` (~> 3.0) — Environment variable loading
- `json` (stdlib) — JSON parsing
- `logger` (stdlib) — Logging

## Testing
- **RSpec** (~> 3.12) — Unit and integration testing
- **Rubocop** (~> 1.50) — Code style enforcement

## Build & Distribution
- **RubyGems** — Gem hosting (`antigravity-sdk`)
- **Bundler** — Dependency management
- **justfile** — Task runner

## Infrastructure
- **localharness** — Antigravity binary (Mach-O arm64)
- **Gemini API** — LLM backend (via API key)
- **stdio** — Process communication protocol
