# Learnings: Building the Antigravity Ruby SDK

Hard-won knowledge from reverse-engineering the Antigravity localharness protocol.
These learnings were discovered 2026-08-10/11 while building the unofficial Ruby SDK.

## Protocol Architecture

### The Go Binary (`localharness`)
- Bundled inside the `google-antigravity` PyPI wheel (`pip download google-antigravity`).
- Extract from `google/antigravity/connections/local/bin/localharness_<os>_<arch>`.
- It's a **Go binary** (~120MB compressed) — show a download/extraction progress indicator!
- **Guard message**: Running the binary directly prints `"This binary should be run by the SDK"` and exits. Useful as a smoke test.
- The Java SDK (by Guillaume Laforge) uses the same extraction approach.
- The binary name variants: `localharness_darwin_arm64`, `localharness_linux_amd64`, etc.
- **NOT** `language_server` — that's a different binary for a different protocol.

### Stdio Handshake (Phase 1)
1. Spawn `localharness` with subcommand: just the binary path, no args needed.
2. Send `InputConfig` as length-prefixed protobuf over stdin:
   - 4-byte **little-endian** length prefix
   - Protobuf-encoded `InputConfig` message (field 1 = api_key string)
3. Read `OutputConfig` as length-prefixed protobuf from stdout:
   - 4-byte little-endian length prefix
   - Contains `ws_url` (field 1) — the WebSocket endpoint

### WebSocket Protocol (Phase 2)
- Connect to the `ws_url` from the handshake.
- All messages are **JSON-encoded protobuf** (camelCase field names!).
- First message: `InitializeConversationEvent` with `HarnessConfig`.

## Key Discoveries

### 1. Custom Tool Calls Arrive as Top-Level Messages
**NOT** inside `stepUpdate.customTool` — they come as independent top-level `toolCall` messages:
```json
{"toolCall": {"id": "...", "name": "get_weather", "argumentsJson": "{\"city\":\"Milan\"}"}}
```
The harness sends BOTH a `stepUpdate` with `customTool` AND a separate `toolCall` message.
The Python SDK handles the `toolCall` message and suppresses the duplicate from `stepUpdate`.

### 2. Tool Response Format: JSON Object, Not Bare String
The `responseJson` field in `ToolResponse` must be a **JSON object**, not a bare string:
```ruby
# WRONG - causes infinite tool-call loop!
responseJson: "Sunny, 28C in Milan"

# CORRECT - model understands the result
responseJson: '{"result": "Sunny, 28C in Milan"}'
```
The Python SDK wraps non-dict results in `{"result": value}` via `tool_result_to_dict()`.

### 3. System Instructions Format
System instructions must use the `custom` format with `part` array:
```ruby
# WRONG
{instructions: ["You are a pirate"]}

# CORRECT (matches protobuf SystemInstruction.custom.part schema)
{custom: {part: [{text: "You are a pirate"}]}}
```

### 4. Tool Parameter Schema: camelCase
Tool definitions in `HarnessConfig` use camelCase for the schema field:
```ruby
# WRONG
{name: "get_weather", parameters_json_schema: "..."}

# CORRECT
{name: "get_weather", parametersJsonSchema: "..."}
```

### 5. Workspace Default Matters
Setting `workspace: Dir.pwd` by default causes the harness to index the directory,
and the model uses built-in tools (list_dir, view_file) to explore it. This makes
even simple "Say OK" prompts take 120+ seconds.

**Fix**: Default workspace to `nil`. Only set when explicitly provided.

### 6. Turn Completion: Use `trajectoryStateUpdate.STATE_FULLY_IDLE`
The authoritative "turn is done" signal is `trajectoryStateUpdate` with
`state: STATE_FULLY_IDLE`, not `stepUpdate` with `state: STATE_DONE`.

**Gotcha**: Don't stop immediately on FULLY_IDLE — wait for the NEXT message
(usually `usageUpdate`) to arrive first, otherwise you miss token counts.

### 7. Usage Update Structure
Usage data arrives as `usageUpdate` messages with nested structure:
```json
{"usageUpdate": {"total": {"promptTokenCount": "3855", ...}, "agents": [...]}}
```
Note: token counts are **strings**, not integers. Always `.to_i` them.

### 8. Message Flow for a Tool Call Turn
```
1. trajectoryStateUpdate (STATE_RUNNING)
2. stepUpdate (STATE_DONE, SOURCE_USER) — user echo
3. usageUpdate
4. toolCall {id, name, argumentsJson}     <-- handle this!
   -> send: {toolResponse: {id, responseJson}}
5. stepUpdate (STATE_ACTIVE, SOURCE_MODEL) — text chunks
6. stepUpdate (STATE_DONE, SOURCE_MODEL)
7. usageUpdate
8. trajectoryStateUpdate (STATE_FULLY_IDLE)
```

### 9. Model Behavior: flash-lite is Agentic
Even with `system_instruction: "Do NOT use any tools"`, `gemini-2.5-flash-lite`
may still use harness built-in tools (list_dir, view_file). Always:
- Set workspace to `nil` for simple tests
- Use specific, constrained prompts
- Keep the 30s per-message timeout to fail fast

## Testing Strategy

### Integration Tests Are Inherently Flaky
LLM-based integration tests depend on model behavior which varies between calls.
Mitigations:
- Use `system_instruction` to constrain model behavior
- Use specific prompts ("Reply with just: A")
- Use 30s per-message timeout (not 120s)
- Don't rely on exact string matching — use regex patterns
- Custom tool tests are more reliable than harness-tool tests

### Test Independence
Each test creates a fresh `Agent` with its own harness process and WebSocket.
The `after(:each)` cleanup with `@agent&.close! rescue nil` is essential.

## Reference: Python SDK Architecture
- `LocalConnection` spawns the binary, does stdio handshake, connects WebSocket
- `EventProcessor` handles all message routing (steps, tools, hooks, policies)
- `ToolRunner` executes custom tools and returns results
- Tool calls are handled in background tasks (`_run_in_background`)
- Turn completion is signaled by `is_idle.set()` + `IDLE_SENTINEL` in step queue
