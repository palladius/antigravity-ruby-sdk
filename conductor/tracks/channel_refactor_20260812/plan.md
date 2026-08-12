# Extract Channel Transport Layer — Implementation Plan

## Phase 1: Channel::Base — Core Shared Logic (TDD)

- [ ] Task: Write specs for `Antigravity::Channel::Base`
  - [ ] Test: session map (`create_session`, `get_session`, `reset_session`, `close_session`)
  - [ ] Test: thread-safe access (Mutex around session operations)
  - [ ] Test: `split_text` with various `max_len` values
  - [ ] Test: `split_text` splits on paragraph > newline > space > hard cut
  - [ ] Test: tool definitions (`find_skills`, `load_skill`) return correct hashes
  - [ ] Test: startup banner generation
  - [ ] Test: JSONL logging helper
- [ ] Task: Implement `lib/antigravity/channel/base.rb`
  - [ ] `ChatSession` inner class (wraps `Antigravity::Agent`)
  - [ ] `@sessions` hash with `Mutex` for thread safety
  - [ ] `split_text(text, max_len)` class method
  - [ ] `build_tools(skill_dirs)` — returns `find_skills` + `load_skill` tool hashes
  - [ ] `log_event(event, detail, chat_id:)` — JSONL logger
  - [ ] `startup_banner` — returns formatted string
  - [ ] `MAX_MESSAGE_LENGTH` constant (default 4096)
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Channel::Telegram — Platform-Specific (TDD)

- [ ] Task: Write specs for `Antigravity::Channel::Telegram`
  - [ ] Test: inherits from `Channel::Base`
  - [ ] Test: `MAX_MESSAGE_LENGTH` is 4096
  - [ ] Test: `send_long_message` splits and sends multiple API calls
  - [ ] Test: Markdown fallback on parse error
  - [ ] Test: command parsing (`/skills`, `/reset`, `/status`, `/help`, `/stop`)
  - [ ] Test: greeting message format
- [ ] Task: Implement `lib/antigravity/channel/telegram.rb`
  - [ ] Requires `channel/base`
  - [ ] `initialize(bot_token:, chat_id: nil, **kwargs)` — calls `super`
  - [ ] `run!` — long-polling loop with error recovery
  - [ ] `send_message(chat_id, text)` — splits + Telegram API + Markdown fallback
  - [ ] `handle_command(chat_id, command)` — dispatch /skills, /reset, etc.
  - [ ] `handle_voice(chat_id, voice_msg)` — download + transcribe + ask
  - [ ] `handle_text(chat_id, text)` — ask agent + send response
- [ ] Task: Move `GeminiAudio` module into `channel/telegram.rb`
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Rewrite Examples — Thin Wrappers

- [ ] Task: Rewrite `examples/08_skill_telegram_bot.rb`
  - [ ] Require `antigravity/channel/telegram`
  - [ ] Config from .env (same env vars)
  - [ ] `Channel::Telegram.new(bot_token:, skills:, workspace:).run!`
  - [ ] Target: < 60 lines
- [ ] Task: Rewrite `examples/08_e2e_telegram_bot.rb`
  - [ ] Require `antigravity/channel/base`
  - [ ] Use `Channel::Base` for session management (no Telegram dependency)
  - [ ] Keep `TestRunner` in the example file (test-specific)
  - [ ] Target: < 120 lines
- [ ] Task: Verify zero code duplication between examples
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: Integration Testing

- [ ] Task: Run full unit test suite (`just test`) — all pass
- [ ] Task: Run E2E test (`just rv-e2e-telegram`) — 13/13 pass
- [ ] Task: Manual Telegram bot test (text, voice, /commands, long messages)
- [ ] Task: Verify message splitting works for long responses
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 5: Documentation & Cleanup

- [ ] Task: Add Channel module docs to README.md
  - [ ] Usage example for Telegram bot
  - [ ] How to create a custom channel (subclass Base)
- [ ] Task: Update CHANGELOG.md and VERSION
- [ ] Task: Delete any dead code from old examples
- [ ] Task: Final commit and push
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
