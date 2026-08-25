# 🧠 Track T001: Thinking Tokens + Interactive Console (GHI #8)

## Goal
Surface thinking/reasoning tokens in streaming output, and build an interactive REPL console (`rv console`) that renders thinking in gray italic and responses in bold — like a Rails console for AI agents.

## Background
The plumbing is **80% done**:
- `conversation.rb` L141-143: already parses `thinkingDelta` from `stepUpdate` messages
- `Message#thinking` accessor exists and is populated
- `LifecycleLogger` already shows byte count of thinking (`324B think`)
- `Chunk` class exists for streaming deltas

What's **missing**:
- `Chunk` does NOT carry thinking deltas — only `content`
- No interactive REPL / console
- No CLI rendering of thinking vs response

## Proposed Changes

### Phase 1: Thinking in Chunks (~30min)

#### [MODIFY] [message.rb](file:///Users/ricc/git/antigravity-ruby-sdk/lib/antigravity/message.rb)
- Add `thinking` attribute to `Chunk` class (it's already in `Message` parent but not used)
- Add `#thinking?` convenience method to distinguish thinking-only chunks from content chunks

#### [MODIFY] [conversation.rb](file:///Users/ricc/git/antigravity-ruby-sdk/lib/antigravity/conversation.rb)
- In `collect_response`, L141-143: yield a **thinking Chunk** to the streaming block when `thinkingDelta` arrives (currently only text deltas yield chunks)
- The chunk should have `content: nil, thinking: thinkingDelta`

#### [NEW] [spec/antigravity/chunk_thinking_spec.rb](file:///Users/ricc/git/antigravity-ruby-sdk/spec/antigravity/chunk_thinking_spec.rb)
- Test that `Chunk.new(thinking: 'foo').thinking?` returns true
- Test that `Chunk.new(content: 'bar').thinking?` returns false
- Test that streaming block receives both thinking and content chunks

---

### Phase 2: Interactive Console (~1.5h)

#### [NEW] [lib/antigravity/console.rb](file:///Users/ricc/git/antigravity-ruby-sdk/lib/antigravity/console.rb)
The main REPL class: `Antigravity::Console`

Features:
- **Prompt**: `agy> ` with readline support (history, Ctrl-C handling)
- **Thinking rendering**: gray italic (`\e[3;90m`) — collapsed to 1 line by default with `...` truncation
- **Response rendering**: bold cyan (`\e[1;36m`) with streaming character-by-character
- **Toggle**: `Ctrl-O` or `/think` command to toggle thinking expansion (show full vs 1-line)
- **Metadata footer**: after each response, show tokens/thinking size/tool calls in dim
- **Special commands**: `/quit`, `/think` (toggle), `/verbose` (toggle model details), `/help`

#### [NEW] [examples/10_console.rb](file:///Users/ricc/git/antigravity-ruby-sdk/examples/10_console.rb)
- Standalone console example: `rv run ruby examples/10_console.rb`
- Optional workspace arg: `rv run ruby examples/10_console.rb ~/my-project`
- Uses `Antigravity::Console` directly

#### Justfile additions:
- `rv-console`: `rv run ruby examples/10_console.rb`
- `rv-console-workspace DIR`: `rv run ruby examples/10_console.rb {{DIR}}`

---

### Phase 3: Tests + Polish (~30min)

#### [NEW] [spec/antigravity/console_spec.rb](file:///Users/ricc/git/antigravity-ruby-sdk/spec/antigravity/console_spec.rb)
- Test Console initialization
- Test thinking toggle logic
- Test rendering methods (truncation, ANSI codes)
- Test special command parsing

> [!IMPORTANT]
> **TDD approach**: All specs written FIRST (failing), then implementation fixes them one by one.

## Verification Plan

### Automated Tests
- `bundle exec rspec spec/antigravity/chunk_thinking_spec.rb` — chunk thinking detection
- `bundle exec rspec spec/antigravity/console_spec.rb` — console unit tests
- `just test` — full regression (should be 227+ tests)

### Manual Verification
- `just rv-console` — interactive session, verify thinking shows in italic gray
- Type a question, verify response streams in bold cyan
- Type `/think` to toggle expansion
- Type `/quit` to exit cleanly
