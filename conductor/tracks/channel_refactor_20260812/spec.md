# Extract Channel Transport Layer — Specification

## Overview

Refactor the monolithic Telegram bot examples (`08_skill_telegram_bot.rb` at 22KB, `08_e2e_telegram_bot.rb` at 12KB) into a proper `Antigravity::Channel` module with a shared base class and a Telegram-specific subclass. This enables lean examples, code reuse, and future messaging platform support (WhatsApp, Discord, Slack).

## Motivation

The two example files share ~60% duplicated code: `ChatSession`, tool definitions, logging, error handling, startup banners. Changes must be made in two places. Adding a new messaging platform (e.g., WhatsApp) would require copying the entire 22KB file and modifying the API calls — classic copy-paste antipattern.

## Architecture

```
lib/antigravity/channel/
  base.rb              # Shared logic for all messaging platforms
  telegram.rb          # Telegram-specific: polling, API, audio download
```

### `Antigravity::Channel::Base`

The base class encapsulates logic that is **genuinely identical** across all messaging platforms:

| Responsibility | Why it's shared |
|----------------|----------------|
| **1:many session map** (`chat_id -> session`) | Every platform has multiple concurrent conversations per bot |
| **Session lifecycle** (create, reset, close, thread-safety) | Universal agent session management |
| **Message splitting** (`split_text(text, max_len)`) | All platforms have message limits (TG: 4096, Discord: 2000, Slack: 40000) |
| **Agent tool definitions** (`find_skills`, `load_skill`) | Platform-agnostic agent tools |
| **Error handling / auto-reset** | Connection errors happen everywhere |
| **JSONL structured logging** | Platform-agnostic observability |
| **Startup banner** | Show config, skills, tools at boot |

Subclasses configure via class-level constants/methods:

```ruby
module Antigravity
  module Channel
    class Base
      MAX_MESSAGE_LENGTH = 4096  # Override in subclass
      
      def initialize(skills: [], tools: [], workspace: nil)
        @sessions = {}           # chat_id => ChatSession
        @mutex = Mutex.new       # Thread-safe session access
        @skills = skills
        @tools = tools
        @workspace = workspace
      end
      
      # Subclass implements:
      # - #run!              (polling loop / webhook server / gateway)
      # - #send_message(chat_id, text)   (platform API call)
      # - #platform_name     ("Telegram", "WhatsApp", etc.)
    end
  end
end
```

### `Antigravity::Channel::Telegram < Base`

Telegram-specific logic only:

| Responsibility | Why it's Telegram-only |
|----------------|----------------------|
| **Long-polling loop** (`getUpdates`) | Other platforms use webhooks/WebSockets |
| **Telegram Bot API** (`send_message`, `getFile`) | Platform-specific HTTP API |
| **Audio file download** (TG file API → local path) | Each platform has different file APIs |
| **Voice transcription flow** (download + Gemini REST) | Download differs per platform, transcription is shared |
| **Slash command parsing** (`/skills`, `/reset`, `/status`) | TG-specific command format |
| **Markdown → Telegram Markdown** conversion | TG uses its own Markdown flavor |

```ruby
module Antigravity
  module Channel
    class Telegram < Base
      MAX_MESSAGE_LENGTH = 4096
      
      def initialize(bot_token:, **kwargs)
        super(**kwargs)
        @bot_token = bot_token
      end
      
      def run!
        # Telegram long-polling loop
      end
      
      def send_message(chat_id, text)
        # Split into chunks, send each via Telegram API
        # Markdown fallback on parse error
      end
    end
  end
end
```

## Functional Requirements

### FR1: Extract `Channel::Base`

- Move `ChatSession` into `Channel::Base` as an inner class or companion
- Move `split_text` / message splitting logic with configurable `MAX_MESSAGE_LENGTH`
- Move tool definitions (`find_skills`, `load_skill`) into base
- Move `log_error` and JSONL logging into base
- Move startup banner generation into base
- Thread-safe session map with `Mutex`

### FR2: Extract `Channel::Telegram`

- Move Telegram API calls (send_message, getFile, getUpdates polling)
- Move `GeminiAudio` module (transcription via REST API)
- Move command handling (`/skills`, `/reset`, `/status`, `/stop`, `/help`)
- Move greeting message logic
- Constructor takes `bot_token:`, optional `chat_id:` for single-user mode

### FR3: Lean Examples

After refactor, the example files should be thin wrappers:

**`08_skill_telegram_bot.rb`** (~30-50 lines):
```ruby
require 'antigravity'
require 'antigravity/channel/telegram'

bot = Antigravity::Channel::Telegram.new(
  bot_token: ENV['TELEGRAM_BOT_TOKEN'],
  skills: [...],
  workspace: ENV['TELEGRAM_WORKSPACE']
)
bot.run!
```

**`08_e2e_telegram_bot.rb`** (~80-100 lines):
```ruby
require 'antigravity'
require 'antigravity/channel/base'

channel = Antigravity::Channel::Base.new(skills: [...], tools: [...])
session = channel.create_session(chat_id: 1)
# Test phases using session.ask(...)
```

### FR4: Backward Compatibility

- All existing bot functionality must work identically after refactor
- E2E test must pass 13/13
- Telegram bot must handle text, voice, commands, long messages

### FR5: Require Path

```ruby
require 'antigravity/channel/telegram'  # loads base automatically
```

The channel module should NOT be auto-loaded by `require 'antigravity'` — it's opt-in since it brings in Telegram-specific dependencies.

## Acceptance Criteria

- [ ] `lib/antigravity/channel/base.rb` exists with shared logic
- [ ] `lib/antigravity/channel/telegram.rb` exists with TG-specific logic
- [ ] `08_skill_telegram_bot.rb` < 60 lines, uses `Channel::Telegram`
- [ ] `08_e2e_telegram_bot.rb` < 120 lines, uses `Channel::Base`
- [ ] All 13 E2E tests pass
- [ ] All 114+ unit tests pass
- [ ] Telegram bot handles: text, voice, /commands, long messages
- [ ] Unit tests for `Channel::Base` (session management, splitting, tools)
- [ ] Unit tests for `Channel::Telegram` (message formatting)
- [ ] No duplicated code between the two example files

## Out of Scope

- WhatsApp / Discord / Slack implementations (future tracks)
- Webhook mode for Telegram (currently long-polling only)
- Multi-user authentication (currently single-user via `CHAT_ID`)
- Persistent session storage (sessions are in-memory only)
