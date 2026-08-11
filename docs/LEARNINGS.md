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
   - 4-byte **little-endian** length prefix (uint32 — the byte count of the following payload)
   - Protobuf-encoded `InputConfig` message (field 1 = storage_directory string, field 2 = bind_address string)
3. Read `OutputConfig` as length-prefixed protobuf from stdout:
   - 4-byte little-endian length prefix (same framing)
   - `OutputConfig` fields: **port** (field 1, varint — localhost port number) + **api_key** (field 2, string — session token)
   - The 4 bytes are NOT the endpoint — they're the length prefix. The actual data follows.
4. WebSocket URL is then constructed: `ws://localhost:{port}/session`

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
# WRONG (bare array — harness ignores it)
{instructions: ["You are a pirate"]}

# CORRECT (matches protobuf SystemInstruction.custom.part schema)
{custom: {part: [{text: "You are a pirate"}]}}
```

### Thinking / Reasoning Tokens
The model's "thinking" (extended reasoning) is NOT a separate out-of-band message.
It arrives **inline** within `stepUpdate` messages as `thinkingContent` parts,
interleaved with the regular `textContent`. The harness passes them through as-is.
The Python SDK exposes them via the step's `content_parts`. Our Ruby SDK currently
does not surface thinking content separately — it only captures the final text.
TODO: Parse `thinkingContent` parts from `stepUpdate` for transparency.

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
The workspace is NOT CWD/PWD — it's sent in `harnessConfig.config.workspaces[].filesystemWorkspace.directory`.
The harness indexes whatever path you send, regardless of your process's working directory.

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

## Developer Experience

### Stateless Examples with `rv` + `bundler/inline`
Use `rv` (Ruby's answer to Python's `uv`) for zero-install script execution.
Each example self-resolves its deps via `bundler/inline`:
```ruby
require 'bundler/inline'
gemfile(true) do
  source 'https://rubygems.org'
  gem 'websocket', '~> 1.2'
end
```
Then just: `rv run ruby -Ilib examples/04_simple_llm_chat.rb` — no `gem install`, 
no `bundle exec`, no state. Gems are cached after first run.

### Timeout Tuning
- **20s default** (dev) is too aggressive — model can take >30s to start responding under load
- **40s** is the sweet spot for integration tests
- **120s** for production/complex agentic tasks
- All configurable via ENV: `ANTIGRAVITY_TIMEOUT_LLM=60 ruby my_agent.rb`
- Per-call override: `agent.ask("complex question", timeout: 90)`

### The FULLY_IDLE Race Condition
When `trajectoryStateUpdate(STATE_FULLY_IDLE)` arrives, it sets `finished = true`.
But the stop condition `finished && msg.key?(:trajectoryStateUpdate)` matches
on the SAME message — exiting before usage data arrives.

**Fix**: Track `finished_this_msg` flag to skip same-message stop:
```ruby
finished_this_msg = false
if traj[:state] =~ /FULLY_IDLE/ && !finished
  finished = true
  finished_this_msg = true
end
# Stop only on SUBSEQUENT metadata messages
if finished && !finished_this_msg && (msg.key?(:trajectoryStateUpdate) || msg.key?(:usageUpdate))
  :stop
end
```

### POLA: Workspace Indexing Warning
Setting a workspace causes the harness to index the entire directory tree.
Always warn users: `"⏳ Indexing workspace: /path — this may take a moment..."`

### Honeypot Technique for Tests
For integration tests that need a workspace, use a tiny "honeypot" fixture
directory (`spec/fixtures/honeypot/`) with just 2 files (~15 lines total).
Indexing is near-instant vs 120+ seconds for a real project.
This makes workspace-dependent tests fast AND deterministic.

## Reference: Python SDK Architecture
- `LocalConnection` spawns the binary, does stdio handshake, connects WebSocket
- `EventProcessor` handles all message routing (steps, tools, hooks, policies)
- `ToolRunner` executes custom tools and returns results
- Tool calls are handled in background tasks (`_run_in_background`)
- Turn completion is signaled by `is_idle.set()` + `IDLE_SENTINEL` in step queue
