# MCP Server Support — Implementation Plan

## Phase 1: Config Layer (TDD)

- [ ] Task: Write specs for `Antigravity::McpConfig`
  - [ ] Test: reads `~/.gemini/settings.json` and extracts `mcpServers`
  - [ ] Test: filters stdio-only servers (has `command` field)
  - [ ] Test: returns empty hash when file missing
  - [ ] Test: returns empty hash when no `mcpServers` key
  - [ ] Test: resolves `$VAR` / `${VAR}` in env values
  - [ ] Test: handles malformed JSON gracefully
- [ ] Task: Implement `lib/antigravity/mcp_config.rb`
  - [ ] Parse `~/.gemini/settings.json` with `JSON.parse`
  - [ ] Filter: keep servers where `config.key?(:command)` (stdio)
  - [ ] Resolve env vars: `value.gsub(/\$\{?(\w+)\}?/) { ENV[$1] }`
  - [ ] Return `{ server_name => { command:, args:, env: } }` hash
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: SDK Integration (TDD)

- [ ] Task: Write specs for config + agent MCP wiring
  - [ ] Test: `Antigravity.configure { |c| c.mcp_servers = {...} }` stores config
  - [ ] Test: `Agent.open(mcp_servers: {...})` accepts per-agent MCP
  - [ ] Test: merge priority (settings.json < global < per-agent)
  - [ ] Test: `harness_config` includes `mcpServers` key in protocol JSON
- [ ] Task: Add `mcp_servers` to `Antigravity::Config`
  - [ ] New attr: `config.mcp_servers` (default: `{}`)
  - [ ] Auto-read: `McpConfig.load_settings` in config initializer
- [ ] Task: Wire MCP into `Agent` constructor
  - [ ] `Agent.new(mcp_servers:)` merges with global config
  - [ ] Pass `mcp_servers` into harness config builder
- [ ] Task: Update `Protocol.initialize_conversation_event` to include `mcpServers`
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Startup Logging & UX

- [ ] Task: Add MCP startup banner
  - [ ] Log: `🔌 MCP Servers: N loaded (stdio: X, skipped: Y)`
  - [ ] Log each server: `📡 server-name (stdio) — command args...`
- [ ] Task: Update Telegram bot to show MCP servers in `/status`
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: E2E Validation — Google Photos MCP

- [ ] Task: Create `examples/09_mcp_agent.rb` minimal example
  - [ ] Reads settings.json automatically
  - [ ] Agent connects with Google Photos MCP
  - [ ] Ask: "List my recent photos" — verify MCP tools are available
- [ ] Task: Update Telegram bot to pick up MCP from settings.json
- [ ] Task: Manual verification with Google Photos MCP
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 5: Documentation & Cleanup

- [ ] Task: Add MCP section to README.md
- [ ] Task: Update CHANGELOG.md and VERSION
- [ ] Task: Final commit and push
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
