# 🎯 Feature Parity Matrix: Python SDK vs Ruby SDK

> **Epic**: [GHI #20](https://github.com/palladius/antigravity-ruby-sdk/issues/20)
> **Generated**: 2026-08-14
> **Python SDK**: [google-antigravity/antigravity-sdk-python](https://github.com/google-antigravity/antigravity-sdk-python)
> **Ruby SDK**: [palladius/antigravity-ruby-sdk](https://github.com/palladius/antigravity-ruby-sdk) v0.4.3

---

## Feature Parity Checklist

### Legend
| Symbol | Meaning |
|--------|---------|
| ✅ | Fully implemented |
| 🟡 | Partial / different approach |
| ❌ | Not implemented |
| ⬜ | N/A or not applicable to Ruby |
| 🔥 | P0 — Must have |
| 🟠 | P1 — Should have |
| 🔵 | P2 — Nice to have |
| ⚪ | P3/P4 — Low priority |

---

## 1. Core Agent Lifecycle

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Agent context manager (`async with` / block) | ✅ `async with Agent(config)` | ✅ `Agent.open { \|a\| }` | — | — |
| Constructor config | ✅ `AgentConfig` Pydantic model | 🟡 kwargs only | Minor | ⚪ |
| `chat()` / `ask()` | ✅ `await agent.chat(prompt)` | ✅ `agent.ask(msg)` | — | — |
| `connect!` / `close!` | ✅ implicit via context manager | ✅ `connect!` / `close!` | — | — |
| Auto-connect on first prompt | ❌ (uses context manager) | ✅ `connect! unless @connected` | Ruby ahead! | — |
| `connected?` | ✅ `is_started` | ✅ `connected?` | — | — |
| Session summary / metadata | ✅ `conversation_id`, `turn_count`, `total_usage` | ✅ `session_summary` hash | — | — |

### Score: 7/7 ✅ (parity achieved)

---

## 2. Streaming & Response

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Text token streaming | ✅ `async for token in response` | ✅ `ask(msg) { \|chunk\| }` | — | — |
| Thinking/reasoning stream | ✅ `async for thought in response.thoughts` | 🟡 `thinking_parts` collected, no dedicated stream | Minor | ⚪ |
| Tool call stream | ✅ `async for call in response.tool_calls` | ❌ No dedicated stream | Gap | 🔵 |
| Raw event stream | ✅ `async for chunk in response.chunks` | 🟡 via hooks `on(:ws_message)` | Different approach | ⚪ |
| `response.text` (full response) | ✅ `await response.text()` | ✅ `response.content` | — | — |
| `response.cancel()` | ✅ Cancel active turn | ❌ No cancellation | Gap | 🟠 |
| `StopReason` | ✅ Enum (MAX_TOKENS, BUDGET, etc.) | ❌ Not tracked | Gap | 🔵 |

### Score: 3/7 ✅ + 2 🟡 + 2 ❌

---

## 3. Custom Tools

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Function registration | ✅ `tools=[my_func]` | ✅ `register_tool(WeatherTool)` | — | — |
| Auto JSON Schema generation | ✅ From type hints | ✅ From `Tool.schema` DSL | — | — |
| Dynamic/block tools | ✅ Lambda/function | ✅ `Tool::Dynamic` | — | — |
| Stateful tools (`ToolContext`) | ✅ `get_state/set_state` | ❌ No ToolContext | Gap | 🟠 |
| Tool unregistration | ✅ `runner.unregister(name)` | ❌ No unregister | Gap | 🔵 |
| Pydantic argument coercion | ✅ Auto-coercion | ⬜ Not applicable (no Pydantic) | N/A | ⬜ |

### Score: 3/5 ✅ + 2 ❌ (excluding N/A)

---

## 4. Agent Skills

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Load from local path | ✅ `skills_paths` | ✅ `add_skill(path)` | — | — |
| Load from GitHub URL | ❌ Not in Python SDK | ✅ `add_skill(github_url)` | Ruby ahead! | — |
| Inline skills | ❌ Not in Python SDK | ✅ `add_inline_skill(...)` | Ruby ahead! | — |
| Skill discovery (`list_skills`) | ❌ Not in Python SDK | ✅ `Agent.list_skills(path)` | Ruby ahead! | — |
| Post-connect skill loading | 🟡 Via model tool calls | ❌ No WebSocket event (GHI #19) | Gap | 🔥 |

### Score: 3/5 ✅ + Ruby leads on 3 features!

---

## 5. Model Context Protocol (MCP)

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| MCP Stdio servers | ✅ `McpStdioServer` | ❌ Not implemented | **Major gap** | 🔥 |
| MCP Streamable HTTP/SSE servers | ✅ `McpStreamableHttpServer` | ❌ Not implemented | **Major gap** | 🔥 |
| Tool filtering (enabled/disabled) | ✅ Per-server filters | ❌ | Gap | 🟠 |
| MCP safety policies | ✅ Fine-grained | ❌ | Gap | 🟠 |

### Score: 0/4 ✅ — **Critical gap**

---

## 6. Policies & Safety

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Declarative policy engine | ✅ `allow()`, `deny()`, `ask_user()` | ❌ No policy engine | **Major gap** | 🔥 |
| Priority hierarchy (Deny > Ask > Allow) | ✅ 6-level precedence | ❌ | Gap | 🔥 |
| `deny_all()` / `allow_all()` | ✅ Presets | ❌ | Gap | 🟠 |
| `workspace_only()` | ✅ Path restriction | ❌ | Gap | 🟠 |
| `confirm_run_command()` | ✅ Interactive approval | ❌ | Gap | 🟠 |
| Argument predicates | ✅ sync/async/Pydantic | ❌ | Gap | 🔵 |
| `FileProtection` guard | ❌ Not in Python SDK | ✅ Ruby has this | Ruby ahead! | — |
| `SecretMasker` guard | ❌ Not in Python SDK | ✅ Ruby has this | Ruby ahead! | — |

### Score: 2/8 ✅ (Ruby has guards, Python has policies — different approaches)

---

## 7. Hooks & Lifecycle

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| `on_session_start` / `on_session_end` | ✅ | ❌ | Gap | 🟠 |
| `pre_turn` / `post_turn` | ✅ | 🟡 `before_prompt` / `after_response` | Same concept | — |
| `pre_tool_call_decide` | ✅ Returns allow/deny | ✅ `before_tool_call` returns :allow/:deny | — | — |
| `post_tool_call` | ✅ | ✅ `after_tool_call` | — | — |
| `on_tool_error` | ✅ Error recovery hooks | ❌ | Gap | 🟠 |
| `on_compaction` | ✅ Context window management | ❌ | Gap | 🔵 |
| `on_interaction` | ✅ | ❌ | Gap | 🔵 |
| Generic event hooks | ❌ | ✅ `hooks.on(:ws_message)` | Ruby ahead! | — |
| Sidecar background workers | ❌ Not in Python SDK | ✅ `AuditLogger`, `VulnerabilityScanner` | Ruby ahead! | — |

### Score: 4/9 ✅ (+ 2 Ruby-ahead features)

---

## 8. Multimodal

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Image input | ✅ `Image(data, mime)` | ❌ | **Gap** | 🟠 |
| Document input (PDF/TXT) | ✅ `Document(data, mime)` | ❌ | Gap | 🟠 |
| Audio input | ✅ `Audio(data, mime)` | 🟡 Voice transcription in Telegram bot only | Gap | 🟠 |
| Video input | ✅ `Video(data, mime)` | ❌ | Gap | 🔵 |
| `from_file()` loader | ✅ Universal file loader | ❌ | Gap | 🟠 |
| Image generation output | ✅ `BuiltinTools.GENERATE_IMAGE` | 🟡 Via skill + harness (nanobanana) | Different approach | ⚪ |

### Score: 0/6 ✅ — **Significant gap** (but some harness-level support exists)

---

## 9. Structured Output

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| `response_schema` (JSON Schema / Pydantic) | ✅ | ❌ | Gap | 🟠 |
| `response.structured_output()` | ✅ Typed extraction | ❌ | Gap | 🟠 |

### Score: 0/2 ✅

---

## 10. Multi-Agent / Subagents

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Dynamic self-delegation | ✅ Clone subagents | ❌ | Gap | 🟠 |
| Static `SubagentConfig` | ✅ Scoped tools/instructions | ❌ | Gap | 🟠 |
| Depth limits (`max_subagent_depth`) | ✅ | ❌ | Gap | 🔵 |
| `allowed_subagents` restrictions | ✅ | ❌ | Gap | 🔵 |

### Score: 0/4 ✅

---

## 11. Triggers (Background Tasks)

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| `every(interval, callback)` | ✅ Periodic triggers | ❌ | Gap | 🔵 |
| `on_file_change(path, callback)` | ✅ Filesystem watcher | ❌ | Gap | 🔵 |
| `@trigger` decorator | ✅ | ❌ | Gap | 🔵 |
| `TriggerContext.send()` | ✅ Push to conversation | ❌ | Gap | 🔵 |

### Score: 0/4 ✅

---

## 12. Session Management

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Session persistence (`save_dir`) | ✅ Save/resume | ❌ | Gap | 🟠 |
| `conversation_id` resume | ✅ Continue session | ❌ | Gap | 🟠 |
| `clear_history()` | ✅ | ❌ | Gap | 🔵 |
| Compaction indices | ✅ Track context window compactions | ❌ | Gap | 🔵 |
| `SessionContinuationMode` | ✅ | ❌ | Gap | 🔵 |

### Score: 0/5 ✅

---

## 13. Configuration & Backends

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Gemini API (API key) | ✅ `GeminiAPIEndpoint` | ✅ Via config | — | — |
| Vertex AI (ADC) | ✅ `VertexEndpoint` | ❌ | Gap | 🟠 |
| LiteRT / Gemma local models | ✅ `LiteRTAgentConfig` | ❌ | Gap | 🔵 |
| OpenAI-compatible (Ollama/LM Studio) | ✅ `LocalOpenAIAgentConfig` | ❌ | Gap | 🔵 |
| Thinking level config | ✅ `ThinkingLevel` enum | ❌ | Gap | 🟠 |
| Service tier (Priority) | ✅ `ServiceTier` enum | ❌ | Gap | 🔵 |
| Budget limits | ✅ `BudgetConfig` | ❌ | Gap | 🟠 |
| Retry config | ✅ `RetryConfig` | ❌ | Gap | 🔵 |
| Custom `app_data_dir` | ✅ | ❌ | Gap | ⚪ |

### Score: 1/9 ✅

---

## 14. Observability & Developer Tools

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| SDK logging | ✅ `DebugConfig` | ✅ `AgentLogger` (JSONL + .log) | — | — |
| Token usage metrics | ✅ `UsageMetadata` | ✅ `session_summary[:tokens]` | — | — |
| OpenTelemetry tracing | ✅ `get_otel_hooks()` | ❌ | Gap | 🔵 |
| Interactive REPL | ✅ `run_interactive_loop()` | 🟡 Example 04 (not library-level) | Gap | 🔵 |
| `StateStore` | ✅ Thread-safe key-value | ❌ | Gap | 🔵 |

### Score: 2/5 ✅

---

## 15. Slash Commands & Builtins

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| `SlashCommand` (planning mode etc.) | ✅ | ❌ | Gap | 🔵 |
| `BuiltinTools` enum | ✅ 12 builtin tools | ❌ | Gap | ⚪ |
| `BuiltinSlashCommandName` | ✅ | ❌ | Gap | ⚪ |

### Score: 0/3 ✅

---

## 16. Error Handling

| Feature | Python | Ruby | Gap | Priority |
|---------|--------|------|-----|----------|
| Error hierarchy | ✅ 5 exception types | ✅ 7 error classes | — | — |
| `AntigravityCancelledError` | ✅ | ❌ (no cancellation) | Gap | 🟠 |

### Score: 1/2 ✅

---

## Example Parity

| Python Example | CUJ | Ruby Equivalent | Status |
|---------------|-----|-----------------|--------|
| `hello_world.py` | Minimal chat | `01_hello_world.rb` | ✅ |
| `streaming.py` | Token streaming + thoughts | `01_hello_world.rb` (partial) | 🟡 |
| `custom_tools.py` | Tool registration | `02_e2e_advanced_agent.rb` | ✅ |
| `hooks.py` | Lifecycle hooks | `02_e2e_advanced_agent.rb` | ✅ |
| `policies.py` | Declarative policies | ❌ None | ❌ |
| `mcp_tools.py` | MCP server integration | ❌ None | ❌ |
| `multimodal.py` | Image/audio/document input | ❌ None | ❌ |
| `structured_output.py` | Schema-enforced JSON | ❌ None | ❌ |
| `subagents.py` | Multi-agent orchestration | ❌ None | ❌ |
| `triggers.py` | Background tasks | ❌ None | ❌ |
| `human_in_the_loop.py` | Interactive approval | ❌ None | ❌ |
| `persistence.py` | Session save/resume | ❌ None | ❌ |
| `budget_limits.py` | Token/call budgets | ❌ None | ❌ |
| `cancellation.py` | Turn cancellation | ❌ None | ❌ |
| `error_handler.py` | Tool error recovery | ❌ None | ❌ |
| `persona_config.py` | System instructions | 🟡 (string-based) | 🟡 |
| `agent_skills.py` | Skill loading | `06_skill_security_audit.rb` | ✅ |
| `observability.py` | Logging + metrics | `03_e2e_safety_and_sidecar.rb` | ✅ |
| `web_tools.py` | Web search / URL read | ❌ None | ❌ |
| `prioritized_inference.py` | Priority tiers | ❌ None | ❌ |
| `slash_commands.py` | Planning mode | ❌ None | ❌ |
| `app_data_dir_override.py` | Custom data dir | ❌ None | ❌ |
| `autonomous_shell.py` | Allow all policies | ❌ None (not needed w/o policies) | ⬜ |
| **Deep Dives** | | | |
| `interactive_cli.py` | Full CLI agent | `04_simple_llm_chat.rb` | 🟡 |
| `agent_middleware.py` | Hook-based middleware | ❌ None | ❌ |
| `async_chat.py` | Multi-agent async chat | ❌ None | ❌ |
| `doc_maintenance_agent.py` | Autonomous doc agent | ❌ None | ❌ |
| `docstring_maintenance_agent.py` | Docstring auditor | ❌ None | ❌ |
| `host_tool_hooks.py` | Full hook observability | ❌ None | ❌ |
| `multimodal_pipeline.py` | Generator/discriminator | ❌ None | ❌ |
| `observability_otel.py` | OpenTelemetry | ❌ None | ❌ |
| `round_based_chat.py` | Round-based multi-agent | ❌ None | ❌ |
| **Ruby Unique** | | | |
| N/A | Safety guards (FileProtection, SecretMasker) | `03_e2e_safety_and_sidecar.rb` | ✅ (Ruby-only) |
| N/A | Telegram bot + voice | `08_skill_telegram_bot.rb` | ✅ (Ruby-only) |
| N/A | GitHub skill resolution | `07_skill_sre_postmortem.rb` | ✅ (Ruby-only) |
| N/A | Full E2E nanobanana pipeline | `09_e2e_nanobanana.rb` | ✅ (Ruby-only) |
| N/A | Workspace analysis | `05_workspace_analysis.rb` | ✅ (Ruby-only) |

### Example Score: 5/32 Python examples covered (+ 5 Ruby-unique examples)

---

## Summary Scorecard

| Category | Features | Covered | Partial | Missing | Parity % |
|----------|----------|---------|---------|---------|----------|
| Core Lifecycle | 7 | 7 | 0 | 0 | **100%** |
| Streaming & Response | 7 | 3 | 2 | 2 | **57%** |
| Custom Tools | 5 | 3 | 0 | 2 | **60%** |
| Agent Skills | 5 | 3 | 0 | 1 | **75%** (Ruby leads on 3!) |
| MCP | 4 | 0 | 0 | 4 | **0%** |
| Policies & Safety | 8 | 2 | 0 | 6 | **25%** (different approach) |
| Hooks & Lifecycle | 9 | 4 | 0 | 5 | **44%** (Ruby has 2 unique) |
| Multimodal | 6 | 0 | 1 | 5 | **8%** |
| Structured Output | 2 | 0 | 0 | 2 | **0%** |
| Multi-Agent | 4 | 0 | 0 | 4 | **0%** |
| Triggers | 4 | 0 | 0 | 4 | **0%** |
| Session Management | 5 | 0 | 0 | 5 | **0%** |
| Config & Backends | 9 | 1 | 0 | 8 | **11%** |
| Observability | 5 | 2 | 1 | 2 | **50%** |
| Slash Commands | 3 | 0 | 0 | 3 | **0%** |
| Error Handling | 2 | 1 | 0 | 1 | **50%** |
| **TOTAL** | **85** | **26** | **4** | **53** | **35%** |

> [!IMPORTANT]
> Ruby SDK is at **~35% feature parity** with the Python SDK.
> However, Ruby has **~8 unique features** not in Python (GitHub skills, inline skills, sidecars, guards, Telegram bot, nanobanana E2E, auto-connect).

---

## Prioritized Gap Closure Plan

### Phase 1: P0 — Foundation (Weeks 1-2)
- [ ] **MCP Server Support** — `McpStdioServer`, `McpStreamableHttpServer` integration
- [ ] **Declarative Policy Engine** — `allow()`, `deny()`, `ask_user()`, precedence hierarchy
- [ ] **Post-connect skill loading** (GHI #19) — WebSocket `loadSkill` event

### Phase 2: P1 — Core Features (Weeks 3-5)
- [ ] **Multimodal Input** — `Image`, `Document`, `Audio`, `Video`, `from_file()`
- [ ] **Structured Output** — `response_schema` + `response.structured_output`
- [ ] **Stateful Tools** — `ToolContext` with `get_state` / `set_state`
- [ ] **Response Cancellation** — `response.cancel()` + `AntigravityCancelledError`
- [ ] **Session Persistence** — `save_dir`, `conversation_id` resume
- [ ] **Vertex AI backend** — `vertex: true` with ADC
- [ ] **Budget Limits** — `BudgetConfig` (max model calls, tokens)
- [ ] **Additional Hooks** — `on_session_start/end`, `on_tool_error`
- [ ] **Thinking Level Config** — `ThinkingLevel` enum

### Phase 3: P2 — Advanced (Weeks 6-8)
- [ ] **Multi-Agent / Subagents** — `SubagentConfig`, dynamic delegation
- [ ] **Triggers** — `every()`, `on_file_change()`, `@trigger`, `TriggerContext`
- [ ] **Interactive REPL** — Library-level `run_interactive_loop`
- [ ] **OpenTelemetry** — `get_otel_hooks()` tracing
- [ ] **Tool call stream** — `response.tool_calls` async iterator
- [ ] **StopReason tracking** — Enum for turn completion reason
- [ ] **Slash Commands** — `SlashCommand`, planning mode
- [ ] **Clear history** / **Compaction** support

### Phase 4: P3/P4 — Polish (Weeks 9+)
- [ ] **LiteRT / Gemma** local model support
- [ ] **OpenAI-compatible** backends (Ollama/LM Studio)
- [ ] **BuiltinTools enum** — Named constants
- [ ] **StateStore** — Thread-safe key-value
- [ ] **RetryConfig** / **DebugConfig**
- [ ] **ServiceTier** — Priority inference
- [ ] **Custom app_data_dir**
- [ ] **Config as first-class object** (Pydantic-like)

---

## Weekly Convergence Check (Cronjob Prompt)

### Reusable Agent Prompt

```
You are the Feature Parity Auditor for the antigravity-ruby-sdk.

1. Clone or update the Python SDK: git -C /tmp/antigravity-sdk-python pull || git clone --depth 1 https://github.com/google-antigravity/antigravity-sdk-python.git /tmp/antigravity-sdk-python
2. Read the Python SDK's README.md, list all examples in examples/, and scan google/antigravity/__init__.py for public API exports.
3. Read the Ruby SDK's CHANGELOG.md, VERSION, and list all examples.
4. Compare against the current feature parity matrix at docs/FEATURE_PARITY.md
5. Report:
   a) NEW features added to Python SDK since last check (diff README/examples)
   b) Features CLOSED in Ruby SDK since last check (diff CHANGELOG)
   c) Updated parity percentage
   d) Top 3 recommended next features to implement
   e) Append a dated entry to docs/FEATURE_PARITY_LOG.md

Focus on DELTA from last check, not full re-audit.
Previous check date is in the last entry of docs/FEATURE_PARITY_LOG.md.
```

### Automation Options
1. **Antigravity `/schedule` command**: `*/schedule cron "0 9 * * 1" "Run feature parity audit"` (every Monday 9am)
2. **GitHub Action**: Weekly cron job that runs the audit prompt and opens an issue with results
3. **Manual**: Run the prompt above weekly in a new Antigravity session

---

## Ruby-Only Features (Advantages)

These features exist in Ruby but NOT in the Python SDK:

| Feature | Ruby Implementation | Value |
|---------|-------------------|-------|
| 🔗 GitHub Skill Resolution | `SkillResolver` auto-clones GitHub repos | Zero-config remote skills |
| 📝 Inline Skills | `add_inline_skill(name:, description:, instructions:)` | Runtime skill creation |
| 🔍 Skill Discovery | `Agent.list_skills(path)` | Enumerate available skills |
| 🛡️ FileProtection Guard | `Guards::FileProtection` | Path-based write blocking |
| 🔐 SecretMasker Guard | `Guards::SecretMasker` | Regex credential redaction |
| 🔄 Sidecar Workers | `Sidecar::AuditLogger`, `VulnerabilityScanner` | Async background monitoring |
| 💎 Emojifiable DSL | `Base.emoji` / `#emoji` on all domain objects | Charming Ruby DX |
| 🤖 Telegram Bot | Production Telegram bot with voice | Real-world integration |
| 🍌 Nanobanana E2E | Full 9-phase autonomous pipeline | Integration test reference |
| ⚡ Auto-connect | `connect! unless @connected` on first prompt | Lazy initialization |
