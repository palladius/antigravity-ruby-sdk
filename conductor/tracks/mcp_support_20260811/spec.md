# MCP Server Support — Specification

## Overview

Add Model Context Protocol (MCP) server support to the Antigravity Ruby SDK, enabling users to configure external MCP tool servers that are plugged into the harness at agent startup. MCP servers provide additional tools to the LLM (e.g., Google Photos search, database queries, custom APIs) without writing Ruby tool code.

## Motivation

The Antigravity harness already supports MCP servers natively — it spawns stdio processes, translates MCP tool schemas to Gemini Function Declarations, and dispatches tool calls. The Python SDK exposes this via `LocalAgentConfig(mcp_servers=[...])`. The Ruby SDK currently has **zero MCP support**, meaning users cannot leverage any MCP servers.

The user already has `~/.gemini/settings.json` configured with 17 MCP servers (including `google-photos` as a stdio server). This config should "just work" with the Ruby SDK.

## Functional Requirements

### FR1: Auto-read `~/.gemini/settings.json`

- On agent startup, the SDK reads `~/.gemini/settings.json` (if it exists)
- Extracts the `mcpServers` key
- Filters to **stdio-only** servers (those with a `command` field) for v1
- Passes matching server configs to the harness via `InitializeConversationEvent`

### FR2: Programmatic MCP Configuration

Users can configure MCP servers in Ruby code:

```ruby
# Global config
Antigravity.configure do |c|
  c.mcp_servers = {
    'google-photos' => {
      command: 'node',
      args: ['/path/to/google-photos-mcp/dist/index.js', '--stdio'],
      env: {
        'GOOGLE_CLIENT_ID' => '...',
        'GOOGLE_CLIENT_SECRET' => '...',
      }
    }
  }
end

# Per-agent override
agent = Antigravity::Agent.open(mcp_servers: { ... })
```

### FR3: Merge Strategy

MCP servers are merged in priority order (last wins):
1. `~/.gemini/settings.json` (auto-discovered)
2. `Antigravity.configure { |c| c.mcp_servers = ... }` (global Ruby config)
3. `Agent.open(mcp_servers: ...)` (per-agent override)

### FR4: Harness Protocol Integration

The SDK passes MCP config to the harness in the `InitializeConversationEvent`:

```json
{
  "config": {
    "models": [...],
    "mcpServers": {
      "google-photos": {
        "command": "node",
        "args": ["/path/to/dist/index.js", "--stdio"],
        "env": { "GOOGLE_CLIENT_ID": "..." }
      }
    }
  }
}
```

The harness handles:
- Spawning the MCP process
- Translating MCP tool schemas to Gemini Function Declarations
- Dispatching tool calls and collecting results
- Environment variable interpolation (`$VAR` / `${VAR}`)

### FR5: Startup Logging

When MCP servers are loaded, log them at startup:

```
🔌 MCP Servers: 1 loaded (stdio: 1, skipped: 16)
   📡 google-photos (stdio) — node /path/to/dist/index.js --stdio
```

### FR6: Day-Zero Validation — Google Photos MCP

The implementation must be validated against the user's existing Google Photos MCP server:
- Server path: `/Users/ricc/git/google-photos-mcp/dist/index.js`
- Transport: stdio (`node ... --stdio`)
- Env vars: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`
- Test: Agent can list/search photos via MCP tools

## Non-Functional Requirements

- **No new gem dependencies**: Use stdlib `json` for parsing settings.json
- **Graceful degradation**: If `~/.gemini/settings.json` doesn't exist or has no `mcpServers`, no error — just zero MCP servers
- **Security**: Env vars from settings.json may reference `$ENV_VAR` — resolve them at load time (matching harness behavior)
- **v1 scope**: Stdio transport only. SSE/HTTP is deferred (tracked separately)

## Acceptance Criteria

- [ ] Auto-reads MCP config from `~/.gemini/settings.json`
- [ ] Filters stdio servers (has `command` field)
- [ ] Passes `mcpServers` in `InitializeConversationEvent`
- [ ] Global config via `Antigravity.configure`
- [ ] Per-agent override via `Agent.open(mcp_servers: ...)`
- [ ] Merge priority: settings.json < global config < per-agent
- [ ] Startup log shows loaded MCP servers
- [ ] Unit tests for config parsing, merging, filtering
- [ ] E2E test with Google Photos MCP server
- [ ] Telegram bot picks up MCP servers from settings.json
- [ ] No errors when settings.json is missing or has no mcpServers

## Out of Scope (v1)

- SSE/HTTP transport MCP servers (Google managed MCPs)
- OAuth/auth provider integration
- `includeTools` / `excludeTools` filtering
- MCP server health checks or auto-restart
- `.agents/mcp_config.json` project-level config (future consideration)
