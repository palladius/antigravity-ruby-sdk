# Technology Stack

## Language

- **Ruby** >= 3.2.0

## Runtime Dependencies

| Gem | Version | Purpose |
|-----|---------|---------|
| `websocket` | ~> 1.2 | WebSocket client for harness IPC |
| `json` | >= 2.6 | Protocol serialization |
| `logger` | >= 1.5 | Structured logging |
| `dotenv` | (optional) | Environment configuration |

## Development Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| `rspec` | ~> 3.12 | BDD testing framework |
| `rubocop` | ~> 1.50 | Code style enforcement |
| `rake` | ~> 13.0 | Build and gem tasks |

## Build & Run Tools

| Tool | Purpose |
|------|---------|
| `just` | Task runner (justfile) |
| `rv` | Zero-install Ruby script executor |
| `localharness` | Antigravity harness binary (auto-fetched from PyPI) |

## Architecture

```
lib/antigravity/
  agent.rb           # Primary facade & DSL
  conversation.rb    # Session state & turn management
  protocol.rb        # JSON protocol for harness communication
  skill.rb           # Skill data model
  skill_resolver.rb  # Local/GitHub/folder skill resolution
  tool.rb            # Tool definition & wrapper
  tool_runner.rb     # Tool execution dispatcher
  guards.rb          # Safety guards (FileProtection, SecretMasker)
  hooks.rb           # Lifecycle hooks
  sidecar.rb         # Telemetry sidecars
  connection/
    binary_fetcher.rb     # Auto-downloads localharness
    local_connection.rb   # Manages harness process
    websocket_client.rb   # WebSocket event loop
```

## Integration Points

- **Telegram Bot**: Full agent integration with voice transcription
- **CLI**: Interactive chat, workspace analysis, skill audit examples
- **Harness Protocol**: WebSocket + JSON (Protobuf planned for v2)
