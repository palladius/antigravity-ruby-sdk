# 🏛️ Antigravity Ruby SDK -- Architecture

> Source: [IMPLEMENTATION_PLAN.md](https://b.corp.google.com/issues/544698718) (b/544698718)
> Updated: 2026-08-13 for v0.4.2

## Original Planned Architecture (v0.1 Vision)

```text
+-----------------------------------------------------------------------+
|                         Ruby Application                              |
|                                                                       |
|   Antigravity::Agent.start(instructions: "...", tools: [MyTools]) do  |
|     stream = agent.stream_chat("Investigate this issue...")           |
|     stream.on_thought   { |t| puts "💭 #{t}" }                        |
|     stream.on_tool_call { |c| puts "🔧 #{c.name}" }                   |
|     stream.on_chunk     { |k| print k }                               |
|   end                                                                 |
+-----------------------------------+-----------------------------------+
                                    | (Ruby DSL & Method Invocation)
+-----------------------------------v-----------------------------------+
|                     Antigravity Ruby SDK (Gem)                        |
|                                                                       |
|  +-------------------------+      +--------------------------------+  |
|  | Antigravity::Toolbox    |      | Antigravity::Harness::Process  |  |
|  | (DSL & Schema Builder)  |      | (Spawns & manages localharness)|  |
|  +-------------------------+      +--------------------------------+  |
|  | Antigravity::Stream     |      | Antigravity::Harness::Client   |  |
|  | (Chunks, Thoughts, Tools|      | (WebSocket + JSON-RPC Events)  |  |
|  +-------------------------+      +--------------------------------+  |
+-----------------------------------+-----------------------------------+
                                    | (WebSocket on 127.0.0.1:<port>)
+-----------------------------------v-----------------------------------+
|                  Core Go Binary (`localharness`)                      |
|                                                                       |
|  - Manages agent state, turns, and session persistence                |
|  - Connects to Google Antigravity / Gemini backends                   |
|  - Sends JSON-RPC tool dispatch requests over WebSocket               |
|  - Streams token deltas and thought/reasoning deltas                  |
+-----------------------------------------------------------------------+
```

## Actual Architecture (v0.4.2)

```text
+-----------------------------------------------------------------------+
|                    Ruby Application Layer                              |
|                                                                       |
|  examples/09_e2e_nanobanana.rb    examples/08_skill_telegram_bot.rb   |
|  ┌──────────────────────────┐     ┌──────────────────────────────┐    |
|  │ E2E Test Pipeline        │     │ Telegram Bot                 │    |
|  │ Phase 0: Sanity          │     │ Per-chat sessions            │    |
|  │ Phase 1: Connect         │     │ find_skills + load_skill     │    |
|  │ Phase 2: Find Skills     │     │ Dynamic skill discovery      │    |
|  │ Phase 3: Load Skill      │     │ Voice/audio support          │    |
|  │ Phase 4: Generate Image  │     │ Image generation via skills  │    |
|  │ Phase 5: Verify          │     └──────────────────────────────┘    |
|  └──────────────────────────┘                                         |
+-----------------------------------+-----------------------------------+
                                    | agent.ask() / agent.connect!
+-----------------------------------v-----------------------------------+
|                 Antigravity Ruby SDK v0.4.2 (Gem)                     |
|                                                                       |
|  +-----------+  +----------+  +------------+  +-------------------+   |
|  | Agent     |  | Hooks    |  | Skill      |  | SkillResolver     |   |
|  | .new()    |  | .on()    |  | .name      |  | .resolve()        |   |
|  | .connect! |  | .emit()  |  | .path      |  | auto-discover     |   |
|  | .ask()    |  | pub/sub  |  | .instruct. |  | GitHub auto-clone |   |
|  | .close!   |  |          |  |            |  |                   |   |
|  +-----------+  +----------+  +------------+  +-------------------+   |
|  +-----------+  +----------+  +------------+  +-------------------+   |
|  | Tool      |  | ToolRun. |  | Conversat. |  | Harness           |   |
|  | .name     |  | dispatch |  | .send_msg  |  | .spawn!           |   |
|  | .desc     |  | .execute |  | .collect   |  | .find_binary      |   |
|  | .schema   |  | Ruby->Go |  | .ws_send   |  | .health_check     |   |
|  +-----------+  +----------+  +------------+  +-------------------+   |
|  +-----------+  +----------+                                          |
|  | Config    |  | Logger   |  🔑 Key insight: truncated tool results  |
|  | .env vars |  | .jsonl   |  keep the model responsive (4 lines     |
|  | .defaults |  | .log     |  not 61). "Tool Result Hygiene"          |
|  +-----------+  +----------+                                          |
+-----------------------------------+-----------------------------------+
                                    | WebSocket (127.0.0.1:<port>)
+-----------------------------------v-----------------------------------+
|              Core Go Binary (`localharness` / `agy`)                  |
|                                                                       |
|  - Spawned automatically, managed via Process#spawn                   |
|  - Auth: ADC / API key / gcloud credentials                          |
|  - Skills: receives skillsPaths[] at InitializeConversationEvent      |
|  - Tools: routes tool_call_request -> Ruby ToolRunner -> response     |
|  - Streams: tokenDelta, thinkingDelta, stateUpdate, stepUpdate        |
+-----------------------------------+-----------------------------------+
                                    | gRPC / HTTPS
+-----------------------------------v-----------------------------------+
|                    Google Gemini Backend                               |
|                                                                       |
|  gemini-2.5-pro / gemini-2.5-flash                                   |
|  Tool calling, thinking, streaming, safety                            |
+-----------------------------------------------------------------------+
```

## 🍌 Nano Banana E2E Flow (v0.4.2)

```text
  Phase 0          Phase 1           Phase 2            Phase 3
  Sanity           Connect           Find Skills        Load Skill
  ┌─────┐         ┌─────────┐       ┌─────────────┐    ┌─────────────┐
  │check│──ok──>  │ Agent   │──ok──>│find_skills  │──> │load_skill   │
  │disk │         │.connect!│       │("nano-      │    │(truncated   │
  │exist│         │WebSocket│       │ banana-     │    │ 4-line       │
  └─────┘         │  open   │       │ ricc")      │    │ summary)     │
                  └─────────┘       └──────┬──────┘    └──────┬──────┘
                                           │                   │
                                     Model calls          Manual fallback
                                     find_skills          if timeout (20s)
                                     tool ✅               adds to skills[]

  Phase 4                              Phase 5
  Generate Image                       Verify
  ┌──────────────────────────┐        ┌──────────────┐
  │ Model builds command     │──ok──> │ File exists?  │
  │ OR failsafe from SKILL.md│        │ Size > 0?     │
  │                          │        │ auto-open 🖼️  │
  │ uv run generate_image.py │        └──────────────┘
  │ --prompt "..." --res 1K  │
  │ ~17s, ~1MB PNG           │        ✅ 9/9 PASS
  └──────────────────────────┘        exit 0
```

## Plan vs Reality Comparison

| Planned Component | Actual Implementation | Status |
|---|---|---|
| `Antigravity::Toolbox` (DSL) | `Antigravity::Tool` (hash-based) | ✅ Simpler, works |
| `Antigravity::Stream` | `Conversation#collect_response` + Hooks | ✅ Event-based |
| `Antigravity::Harness::Installer` | `Antigravity::Harness#find_binary` | ✅ Uses existing install |
| `Antigravity::Harness::Client` | `Connection::WebSocketClient` | ✅ Raw websocket gem |
| `Antigravity::Protocol::EventRouter` | `Conversation` + `Hooks` pub/sub | ✅ 3-line hooks system |
| `Antigravity::Skills::Loader` | `SkillResolver` + `Skill` | ✅ + GitHub auto-clone |
| `Agent.start` block DSL | `Agent.new` + `connect!` + `ask` | ✅ Explicit lifecycle |
| `stream.on_thought` | `hooks.on(:ws_message)` | ✅ Generic, composable |
| Protobuf handshake | JSON over WebSocket | 🔮 Backlog |
| MCP server support | Not yet | 📋 Planning |
