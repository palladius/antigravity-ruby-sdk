# Telegram Integration: Design Debate

> **Status**: RFC (Request for Comments)
> **Author**: Riccardo Carlesso + Antigravity Agent
> **Date**: 2026-08-11
> **Related**: GHI #13, `examples/08_skill_telegram_bot.rb`

## Context

The Telegram bot integration started as an `examples/` script and has grown to include:

- Text chat with Antigravity Agent (via harness)
- Voice/audio transcription (Gemini multimodal REST API)
- Dynamic skill discovery and hot-loading (`find_skills`, `load_skill`)
- File tools with workspace guard (SCARY MODE)
- Per-chat agent sessions with independent history
- 409 Conflict retry handling

The question: **where should this live, and how should it handle the 1:N problem?**

---

## Decision 1: Where Should the Code Live?

### Option A: `examples/` (current)

```
examples/08_skill_telegram_bot.rb  (~500 lines, single file)
```

| Pros | Cons |
|------|------|
| Self-contained, easy to read | No test coverage of internals |
| No SDK dependency bloat | Copy-paste if someone wants to customize |
| Fast iteration, no API contract | Monolithic, growing unwieldy |
| `bundler/inline` = zero setup | Can't `require 'antigravity/telegram'` |

### Option B: SDK Integration (`lib/antigravity/integrations/telegram.rb`)

```ruby
# Usage would be:
agent = Antigravity::Agent.new(skills: [...])
bot = Antigravity::Telegram::Bot.new(agent, token: ENV['TELEGRAM_BOT_TOKEN'])
bot.start!
```

| Pros | Cons |
|------|------|
| Testable, versioned, documented | Adds `telegram-bot-ruby` as dependency |
| Reusable across projects | Heavier SDK footprint |
| Clean API: `Agent#telegram!` | More complex release cycle |
| PID locking built-in | Over-engineering for single user? |

### Option C: Separate Gem (`antigravity-telegram`)

```ruby
# Gemfile
gem 'antigravity'
gem 'antigravity-telegram'
```

| Pros | Cons |
|------|------|
| Clean separation of concerns | Yet another repo to maintain |
| Optional install, no SDK bloat | Version coordination pain |
| Could support other messengers | Premature abstraction |

### Recommendation

**Phase 1 (now)**: Keep in `examples/`, ship it, get feedback.
**Phase 2**: Move core logic to `lib/antigravity/integrations/telegram.rb` with `telegram-bot-ruby` as optional dependency (loaded on `require`).
**Phase 3**: Extract to separate gem only if other messengers (Discord, Slack, WhatsApp) are added.

---

## Decision 2: The 1:N Problem (One Token, Many CLIs)

### The Problem

Telegram bot tokens support only ONE active long-polling connection. When a second process starts polling:

```
Instance 1: polling... ──────► gets 409 Conflict ──────► retries, survives
Instance 2: starts    ──────► steals one message ──────► 409 ──────► crashes
```

Observed behavior (2026-08-11):
- Instance 2 captured a "Ping" that Instance 1 never saw
- Instance 1 got a 409 error but recovered
- Instance 2 crashed on its own 409
- Instance 1 continued operating

### Option A: PID Lockfile (Unix Standard)

```ruby
LOCK_FILE = "/tmp/antigravity-telegram-#{Digest::SHA256.hexdigest(token)[0, 8]}.lock"

def acquire_lock!
  if File.exist?(LOCK_FILE)
    pid = File.read(LOCK_FILE).strip.to_i
    if process_alive?(pid)
      abort "Another bot instance (PID #{pid}) is already running. Kill it first."
    else
      warn "Stale lock found (PID #{pid} dead). Stealing lock."
    end
  end
  File.write(LOCK_FILE, "#{Process.pid}\n#{Socket.gethostname}\n#{Time.now.iso8601}")
  at_exit { File.delete(LOCK_FILE) rescue nil }
end
```

| Pros | Cons |
|------|------|
| Simple, proven Unix pattern | Stale locks if process crashes without cleanup |
| No external dependencies | Doesn't work across machines |
| Clear error message | `at_exit` may not fire on SIGKILL |

### Option B: 409 Retry with Backoff (current)

```ruby
rescue Telegram::Bot::Exceptions::ResponseError => e
  if e.message.include?('409')
    sleep 5
    retry
  end
end
```

| Pros | Cons |
|------|------|
| Zero infrastructure | Messages can be stolen/lost |
| Self-healing | No clear "who owns the channel" |
| Works across machines | Unpredictable behavior |

### Option C: Webhook Mode (Instead of Long-Polling)

Replace long-polling with a webhook endpoint. Telegram POSTs to your server.

```ruby
# Instead of bot.listen (long-polling):
# Set webhook: https://your-server.com/telegram/webhook
# Run a small Sinatra/Rack server to receive POSTs
```

| Pros | Cons |
|------|------|
| No 1:N problem (Telegram pushes to ONE URL) | Needs a public URL (ngrok, Cloud Run) |
| More efficient (no polling) | More complex setup |
| Production-grade pattern | Overkill for local dev |

### Recommendation

**Phase 1 (now)**: 409 retry (current) + PID lockfile as safety net.
**Phase 2**: PID lockfile required, with `--force` flag to steal lock.
**Phase 3**: Webhook mode for production deployments (Cloud Run).

---

## Decision 3: Session Architecture

### Current: Per-Chat Sessions

```ruby
SESSIONS = { chat_id => ChatSession }

# Each ChatSession has:
# - Its own Agent instance (with own harness connection)
# - Its own conversation history
# - Its own loaded skills
# - Shared tools (FILE_TOOLS are global)
```

### Concerns

1. **Memory**: Each Agent spawns a harness subprocess. 10 chats = 10 subprocesses.
2. **Skill loading**: `load_skill` adds to ONE session. Should it propagate to all?
3. **Cleanup**: Sessions are never cleaned up unless `/reset` or `/stop`.
4. **Persistence**: History is lost on restart. Should we persist to disk?

### Future Options

| Feature | Complexity | Value |
|---------|-----------|-------|
| Session timeout (close after 30min idle) | Low | High |
| Persist history to JSONL per chat_id | Medium | High |
| Shared skill registry across sessions | Medium | Medium |
| Max concurrent sessions limit | Low | Medium |
| Session transfer between CLI instances | High | Low |

---

## Decision 4: Tool Sandboxing

### Current: Workspace Guard

```ruby
workspace_guard = ->(path) {
  expanded = File.expand_path(path, WORKSPACE_PATH)
  unless expanded.start_with?(WORKSPACE_PATH)
    raise "Access denied: #{path} is outside workspace"
  end
  expanded
}
```

### Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Symlink escape (`ln -s / workspace/escape`) | High | `File.realpath` check |
| `../../../etc/passwd` traversal | High | Already handled by guard |
| Large file writes (disk bomb) | Medium | Max file size limit |
| Accidental overwrite of important files | Medium | Backup before write? |
| `delete_file` on wrong path | High | Confirmation for delete? |

### Recommendation

Add `File.realpath` check to prevent symlink escapes. Consider a `--confirm-deletes` flag.

---

## Open Questions

1. Should `find_skills` be available even WITHOUT `TELEGRAM_WORKSPACE`? (Currently it's in `FILE_TOOLS` which requires workspace)
2. Should the bot support inline keyboards for skill selection? (Telegram UI)
3. Should voice transcription use the agent's own model or a dedicated one? (Currently: same)
4. Multi-language system instructions? (Italian greeting but English agent)
5. Should there be a `/shell` command for remote command execution? (VERY SCARY)

---

## References

- [Telegram Bot API: getUpdates](https://core.telegram.org/bots/api#getupdates)
- [telegram-bot-ruby gem](https://github.com/atipugin/telegram-bot-ruby)
- [Antigravity Ruby SDK](https://github.com/palladius/antigravity-ruby-sdk)
- Audio transcription research: `gemini-3.5/3.6-flash` achieves ~2.3% WER
