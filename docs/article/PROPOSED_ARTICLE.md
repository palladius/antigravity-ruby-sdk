# Building an Agentic Telegram Bot in Ruby with Google's Antigravity SDK

*What if your Ruby app could think, learn new skills at runtime, and tell you exactly what it's doing -- all in a single terminal line?*

![Hero: Ruby gemstone connected to Telegram and a terminal](images/hero.jpg)

## Introduction

When [Guillaume Laforge](https://glaforge.dev/posts/unofficial-antigravity-sdk-for-java/) built the unofficial Antigravity SDK for Java back in July, I thought: *"If Java gets one, Ruby deserves one too."* So I built one. And then I built a Telegram bot on top of it. And then the bot learned to discover and load skills at runtime. And then I needed to debug why the model kept going silent after exactly 7 WebSocket messages.

This is that story.

The [Antigravity Ruby SDK](https://github.com/palladius/antigravity-ruby-sdk) is an unofficial Ruby wrapper around Google's Antigravity harness -- the same engine that powers Gemini CLI, Antigravity IDE, and Antigravity 2.0. It gives your Ruby code access to Gemini's full agentic capabilities: tool calling, skill loading, streaming responses, and now, a generic event system for real-time observability.

## How It Works

The architecture is deliberately simple. Your Ruby process talks to a local Go binary (the "harness") over WebSocket. The harness handles the heavy lifting: authentication, model communication, tool execution, and safety policies. Your SDK just needs to speak JSON.

![Architecture: User -> Telegram -> Ruby Bot -> SDK -> WebSocket -> Harness -> Gemini](images/architecture.jpg)

```
User --> Telegram --> Ruby Bot --> Antigravity SDK --> WebSocket --> Harness --> Gemini
                                       |
                                  Skills | Hooks | Tools
```

## Getting Started: 5 Lines to Your First Agent

```ruby
require 'antigravity'

agent = Antigravity::Agent.new
agent.connect!
response = agent.ask("What's the mass of the Sun?")
puts response
```

That's it. The SDK spawns the harness, opens a WebSocket, sends your prompt, streams the response, and returns the full text. Under the hood, about 2000 lines of Ruby handle connection management, session lifecycle, tool routing, skill resolution, and structured logging.

## Building a Telegram Bot

The real fun starts when you connect the SDK to a messaging platform. Here's the core loop of our Telegram bot:

```ruby
bot.listen do |message|
  session = sessions[message.chat.id] ||= ChatSession.new(
    skills: SKILL_DIRS,
    tools: [find_skills_tool, load_skill_tool]
  )

  response = session.ask(message.text)
  bot.api.send_message(chat_id: message.chat.id, text: response)
end
```

Each Telegram chat gets its own `ChatSession` with its own Antigravity agent. The agent starts with a "metaskill" -- a skill that knows how to find and load other skills. Users can ask the bot to learn new capabilities on the fly:

> **User:** Find the riccardo-todo skill
> **Bot:** Found `riccardo-todo` at `/path/to/skills/riccardo-todo`
> **User:** Load it
> **Bot:** *[restarts session with new skill]* Loaded! I now know about your to-do list.
> **User:** Where's my to-do file?
> **Bot:** According to the skill, it's at `~/obsidian/TODOs/TODOz.md`

## Skills: Superpowers for Your Agent

Skills are the [Agent Skills](https://agentskills.io) standard -- a `SKILL.md` file with YAML frontmatter and markdown instructions. The SDK supports:

```ruby
# Local paths
agent = Antigravity::Agent.new(skills: ["/path/to/my-skill"])

# GitHub URLs (auto-cloned to ~/.antigravity/cache/)
agent = Antigravity::Agent.new(skills: ["https://github.com/org/skills-repo"])

# Runtime discovery
agent.add_skill("/discovered/path", skill_name: "new-skill")

# Inline skills (no files needed)
agent.add_inline_skill(
  name: "greeter",
  description: "Greets users in Italian",
  instructions: "Always greet the user with 'Bella vecchio!'"
)
```

The runtime loading now attempts dynamic skill loading within the same session. If the model struggles to invoke the new skill, we fall back to a manual failsafe that reads the skill definition and executes it directly.

## The Hooks System: 3 Lines That Changed Everything

This is where Ruby shines. We needed debug observability for the WebSocket traffic, but didn't want to pollute the core `Conversation` class. The solution: a generic pub/sub event system.

**The entire core change:**

```ruby
# lib/antigravity/hooks.rb -- 2 methods added
def on(event, &block)
  @listeners[event.to_sym] << block if block_given?
end

def emit(event, *args)
  @listeners[event.to_sym].each { |cb| cb.call(*args) }
end

# lib/antigravity/conversation.rb -- 1 line added
@hooks&.emit(:ws_message, msg)
```

That's it. Three lines in the SDK. Everything else lives in the consumer:

```ruby
# In your app, test, or bot -- NOT in the SDK
agent.hooks.on(:ws_message) do |msg|
  if (s = msg[:stepUpdate])
    puts "Tool: #{s[:textDelta]}" if s[:target] =~ /ENVIRONMENT/
    print "." if s[:thinkingDelta]
  end
end
```

**Zero lines of debug code in the core SDK.** All observability is opt-in, external, and composable. This is the Ruby way.

### Ruby idiom spotlight: `Hash.new` with default block

```ruby
@listeners = Hash.new { |h, k| h[k] = [] }
```

This auto-creates an empty array for any new event name. No `if @listeners[event].nil?` boilerplate. When you call `@listeners[:ws_message]`, it returns `[]` if the key doesn't exist yet. Chef's kiss.

## The Dynamic TUI Status Line

The hooks system's first real consumer was a dynamic terminal status line for the E2E test. One line that overwrites itself in-place:

```
     🏃 running 💭💭💭 ⏳42s 7↕
```

The implementation uses ANSI escape codes (`\r\e[K`), a state emoji map, and a background ticker thread:

```ruby
# Background thread ticks every second
@_ticker = Thread.new do
  loop do
    sleep 1
    _render_status if @_status[:active]
  end
end

def _render_status
  icon = case @_status[:state]
         when /RUNNING/ then '🏃'
         when /IDLE/    then '😴'
         when /CANCEL/  then '🛑'
         else '⏳'
         end

  elapsed = (Time.now - @_status[:started]).to_i
  line = "     #{icon} #{@_status[:state].downcase}"
  line += " #{@_status[:dots]}" unless @_status[:dots].empty?
  line += " ⏳#{elapsed}s #{@_status[:msg_count]}↕"

  print "\r\e[K#{line[0, 79]}"
  $stdout.flush
end
```

The result: you ALWAYS know what the agent is doing. Thinking? You see `💭💭💭`. Calling tools? You see `🔧 Find todo files`. Stuck? The timer keeps ticking: `⏳42s... ⏳43s... ⏳44s...`

## Debugging a Model Hang: A War Story

With the TUI in place, we caught a fascinating bug. When loading a new skill dynamically in Phase 3 of our E2E test, the model would sometimes hang -- every single time, with the exact same pattern:

```
     🏃 running 💭💭💭💭💭 ⏳2s 7↕
     🏃 running 💭💭💭💭💭 ⏳3s 7↕
     ...
     🏃 running 💭💭💭💭💭 ⏳59s 7↕
  ⚠️  Error: Wall-clock timeout after 60s
```

The model sent exactly 5 thinking deltas at the 2-second mark, then went completely silent. No `DONE`, no `FULLY_IDLE`, no error -- just nothing.

### What we learned the hard way

1. **Large tool results cause "thinking hangs".** Our `load_skill` tool was originally returning the entire 61-line `SKILL.md` content. This massive context dump overwhelmed the model, causing it to spin its wheels indefinitely. By optimizing the tool to return a concise 4-line summary (name, script path, description, usage hint), the model processed it instantly.

2. **Failsafes are better than session restarts.** We used to restart the entire session when loading a skill to ensure the model recognized it. Now, we use dynamic skill loading in the same session. If the model still times out in Phase 4 (acting on the new skill), our harness kicks in with a manual failsafe: it reads the `SKILL.md` and builds the `uv run` command directly, bypassing the agent loop entirely.

3. **Idle timeout != wall-clock timeout.** The SDK's `timeout:` parameter is a per-message idle timeout. If the model keeps sending tool calls, each response resets the timer. We added `Timeout.timeout()` as a hard wall-clock deadline.

With these improvements, all 9 E2E tests now pass consistently in around 73 seconds. This bug and its resolution are tracked in [Issue #16](https://github.com/palladius/antigravity-ruby-sdk/issues/16).

## Ruby Tips for Agent Code

A few patterns that proved invaluable:

### Tool Result Hygiene

Keep your tool responses concise. Models struggle with large, unstructured text dumps from tools (as seen in our model hang war story). Return only the essential metadata the agent needs to make its next decision, rather than full file contents or verbose logs.

### Safe navigation for optional components
```ruby
@hooks&.emit(:ws_message, msg)  # If hooks is nil, does nothing
```

### `ensure` for guaranteed cleanup
```ruby
def ask(text, wall_timeout: 180)
  @_status[:active] = true
  Timeout.timeout(wall_timeout) { ... }
ensure
  @_status[:active] = false  # ALWAYS runs, even on Timeout::Error
  print "\r\e[K"             # Clear the status line
end
```

### Monkey-patching for terminal aesthetics
```ruby
class String
  def to_bold    = "\e[1m#{self}\e[0m"
  def to_cyan    = "\e[36m#{self}\e[0m"
  def to_green   = "\e[32m#{self}\e[0m"
  def to_gray    = "\e[90m#{self}\e[0m"
  def to_red     = "\e[31m#{self}\e[0m"
  def to_yellow  = "\e[33m#{self}\e[0m"
end

puts "  ✅ PASS".to_green
puts "  ❌ FAIL".to_red
```

### Regex case/when for state machines
```ruby
icon = case state
       when /RUNNING/ then '🏃'
       when /IDLE/    then '😴'
       when /CANCEL/  then '🛑'
       else '⏳'
       end
```

## What's Next

The SDK is at v0.4.2 with all 9 E2E tests passing consistently. Here's what's coming:

| Feature | Status | Issue |
|---------|--------|-------|
| Mid-session skill loading | Shipped | [#15](https://github.com/palladius/antigravity-ruby-sdk/issues/15) |
| MCP server support | Planning | -- |
| Channel abstraction (Telegram/WhatsApp/Discord) | Planning | -- |
| Protobuf handshake | Backlog | -- |
| Rails integration | P4 Vision | -- |

## Your Turn

The [Antigravity Ruby SDK](https://github.com/palladius/antigravity-ruby-sdk) is open source and ready for experimentation. If you're a Rubyist who's been curious about building AI agents, this might be your entry point.

```bash
git clone https://github.com/palladius/antigravity-ruby-sdk
cd antigravity-ruby-sdk
cp .env.dist .env  # add your config
ruby examples/01_hello_world.rb
```

I'm genuinely curious how you'd use this. Would you build a Slack bot? A Rails assistant? A CLI tool that learns from your codebase? Open an issue, send a PR, or just say hello.

And if you want to see what Guillaume built for Java, check out [his article](https://glaforge.dev/posts/unofficial-antigravity-sdk-for-java/) -- it's the post that started this whole Ruby adventure.

---

*Riccardo Carlesso is a Developer Advocate for Google Cloud, focusing on Open Source, Developer Experience, and occasionally building things that probably didn't need to exist but are wonderful anyway.*

*The Antigravity Ruby SDK is an unofficial, community project. It is not an official Google product.*
