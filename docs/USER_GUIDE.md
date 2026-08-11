# Antigravity Ruby SDK - User Guide

> The unofficial, idiomatic Ruby SDK for Google Antigravity.
> Build autonomous AI agents that can think, use tools, and navigate your codebase.

---

## How It Works

The Ruby SDK doesn't call the Gemini API directly. Instead, it talks to a **local Go binary** called `localharness` that ships inside the Antigravity app. The harness handles all the heavy lifting: model calls, tool orchestration, memory, subagents, and safety policies. The SDK just speaks its protocol.

```
Ruby SDK                              localharness (Go binary)         Gemini API
   |                                       |                              |
   |-- Process.spawn(binary) ------------>| starts                       |
   |-- stdin: [4B LE len][InputConfig] -->|                               |
   |<- stdout: [4B LE len][OutputConfig] -| (port + api_key)             |
   |                                       |                              |
   |-- ws://localhost:<port>/ ----------->|                               |
   |-- InitializeConversationEvent ------>|                               |
   |<- InitializeConversationResponse ----|                               |
   |                                       |                              |
   |-- InputEvent(user_input) ----------->|-- generateContent ---------->|
   |<- OutputEvent(text_delta) -----------|<- streaming chunks ----------|
   |                                       |                              |
   |<- OutputEvent(tool_call) ------------|  "run Ruby tool X"           |
   |-- InputEvent(tool_response) -------->|  "here's the result"         |
   |<- OutputEvent(text_delta) -----------|  continues with result       |
```

### The Two Phases

**Phase 1: Stdio Handshake** (binary protobuf, one-shot)

The SDK spawns `language_server localharness` as a subprocess. It writes an `InputConfig` message to the process's stdin (4-byte little-endian length prefix + raw protobuf bytes). The harness responds on stdout with an `OutputConfig` containing a WebSocket `port` and an `api_key`. This handshake takes ~200ms.

**Phase 2: WebSocket Session** (JSON over WebSocket, bidirectional)

Once the port is known, the SDK opens a WebSocket to `ws://localhost:<port>/` with the `x-goog-api-key` header. All subsequent communication happens over this channel using JSON-serialized protobuf messages:

- **SDK -> Harness**: `InputEvent` (user prompts, tool responses, halt requests)
- **Harness -> SDK**: `OutputEvent` (text deltas, tool calls, step updates, usage metadata)

### Where the Binary Lives

The SDK searches for the harness binary in this order:

1. `ANTIGRAVITY_HARNESS_PATH` environment variable
2. `/Applications/Antigravity.app/Contents/Resources/bin/language_server` (macOS)
3. `~/.antigravity/bin/language_server`
4. `which language_server` (PATH lookup)

You can also extract it from the official Python SDK's PyPI wheel:

```bash
pip download google-antigravity --only-binary=:all: --platform macosx_11_0_arm64 -d /tmp/wheels
unzip /tmp/wheels/google_antigravity-*.whl -d /tmp/extracted
# Binary is at: /tmp/extracted/google/antigravity/bin/localharness
```

---

## Installation

Add to your `Gemfile`:

```ruby
gem 'antigravity-sdk'
```

Then:

```bash
bundle install
```

### Dependencies

The SDK keeps its dependency tree intentionally small:

| Gem | Purpose | Weight |
|-----|---------|--------|
| `websocket-client-simple` | WebSocket client for harness communication | ~50 KB |
| (stdlib) `open3`, `json`, `socket` | Process spawn, JSON parsing, IO | 0 KB |

Notably, we do **not** depend on `google-protobuf` (3.6 MB). The two tiny handshake messages are encoded by hand. See [Issue #7](https://github.com/palladius/antigravity-ruby-sdk/issues/7) for the future-proofing plan.

---

## Quickstart

### Basic Chat

```ruby
require 'antigravity'

Antigravity::Agent.open do |agent|
  response = agent.ask('What files are in the current directory?')
  puts response.content
end
```

### Streaming

```ruby
Antigravity::Agent.open do |agent|
  agent.ask('Write a haiku about Ruby') do |chunk|
    print chunk.content if chunk.content
  end
  puts # newline
end
```

### Custom Tools

Define tools that the AI agent can call. The harness invokes your Ruby block when the model decides to use the tool:

```ruby
weather_tool = Antigravity::Tool.define(:get_temperature,
  desc: 'Gets the current temperature for a city in Celsius',
  params: { city: { type: :string, description: 'City name' } }
) { |city:| "22C in #{city}" }

Antigravity::Agent.open(
  system_instruction: 'Use the get_temperature tool for weather questions.',
  tools: [weather_tool]
) do |agent|
  response = agent.ask('Temperature in Milan?')
  puts response.content  # => "The temperature in Milan is 22C."
end
```

### System Instructions

```ruby
Antigravity::Agent.open(
  system_instruction: 'You are an Italian translator. Always respond in Italian.'
) do |agent|
  response = agent.ask('Say hello')
  puts response.content  # => "Ciao! Come posso aiutarti?"
end
```

---

## Architecture

```
                       +-------------------+
                       |   Your Ruby App   |
                       +-------------------+
                               |
                    Antigravity::Agent.open
                               |
                  +----------------------------+
                  |      Antigravity::Agent     |
                  |  - system_instruction       |
                  |  - tools, hooks, sidecars   |
                  +----------------------------+
                               |
                  +----------------------------+
                  |  Antigravity::Conversation  |
                  |  - history, turn count      |
                  |  - chat(prompt, &block)      |
                  +----------------------------+
                               |
            +--------------------------------------+
            | Antigravity::Connection::LocalConnection |
            |  - find_binary! (discovery)           |
            |  - spawn + stdio handshake            |
            |  - WebSocket event loop               |
            +--------------------------------------+
                     |                    |
              [stdin/stdout]        [WebSocket]
                     |                    |
            +--------------------------------------+
            |     language_server localharness      |
            |  (Go binary from Antigravity.app)     |
            +--------------------------------------+
                               |
                        [HTTPS/gRPC]
                               |
                    +-------------------+
                    |    Gemini API     |
                    +-------------------+
```

### Key Classes

| Class | Responsibility |
|-------|---------------|
| `Agent` | Top-level user API. Holds config, tools, hooks. |
| `Conversation` | Manages chat history and turn-taking. |
| `Connection::LocalConnection` | Binary discovery, process lifecycle, WebSocket transport. |
| `Protocol` | Hand-rolled protobuf encoding for the stdio handshake. |
| `ToolRunner` | Registers, resolves, and executes custom tool callbacks. |
| `Tool` / `Tool::Dynamic` | Tool definitions with JSON schema generation. |
| `Message` | Normalized response object with content, role, tokens. |

### Message Flow

1. **You call** `agent.ask("prompt")` with an optional streaming block.
2. **Agent** passes the prompt to `Conversation#chat`.
3. **Conversation** wraps it in an `InputEvent` and sends it over WebSocket.
4. **Harness** calls Gemini, streams `OutputEvent` chunks back.
5. **SDK** yields each `text_delta` chunk to your block (if streaming).
6. If the model calls a **tool**, the harness sends a `tool_call` event.
7. **ToolRunner** executes your Ruby block and sends a `tool_response` back.
8. The harness continues the conversation with the tool result.
9. When the turn ends, `ask` returns a `Message` with the full response.

---

## Configuration

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `GEMINI_API_KEY` | API key for Gemini (passed to harness) | Required |
| `ANTIGRAVITY_HARNESS_PATH` | Override harness binary location | Auto-detect |
| `ANTIGRAVITY_LOGGER` | Enable/disable auto-logging (`true`/`false`) | `true` |

### Programmatic Config

```ruby
Antigravity.configure do |config|
  config.default_model = 'gemini-2.5-flash-lite'
end
```

---

## Testing

```bash
# Unit tests only (fast, no harness needed)
just test

# Integration tests (requires localharness + GEMINI_API_KEY)
just integration

# Everything
just all-tests
```

Integration tests are tagged `:integration` and automatically skip if the harness binary or API key is missing.

---

## Credits

This SDK's architecture is inspired by:
- The [official Antigravity Python SDK](https://github.com/google-antigravity/antigravity-sdk-python/) by Google
- The [unofficial Antigravity Java SDK](https://medium.com/google-cloud/the-unofficial-antigravity-sdk-for-java-1d2d1e4834fe) by Guillaume Laforge
- [RubyLLM](https://github.com/crmne/ruby_llm) for idiomatic Ruby streaming patterns
