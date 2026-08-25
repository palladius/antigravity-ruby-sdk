---
name: using-antigravity-ruby-sdk
description: Guide for AI agents and developers on building autonomous agents with the Antigravity Ruby SDK (tools, skills, policies, hooks).
---

# Using the Antigravity Ruby SDK 🛰️

This skill provides comprehensive instructions for agents and developers building applications with the **Antigravity Ruby SDK**.

---

## 1. Core Concepts & Architecture

The Ruby SDK does not talk to the Gemini API directly. Instead, it manages a local Go engine (`localharness`) that handles model orchestration, tool dispatch, memory, and safety.

```
Ruby SDK                                localharness (Go engine)        Gemini API
   |                                       |                              |
   |-- Process.spawn(binary) ------------>| starts                       |
   |-- stdin/stdout: Stdio Handshake ---->| (returns port + api_key)     |
   |-- ws://localhost:<port>/ ----------->|                              |
   |-- InputEvent(user prompt) ---------->|-- generateContent ---------->|
   |<- OutputEvent(streaming chunks) -----|<- streaming response --------|
   |<- OutputEvent(tool_call) ------------|                              |
   |-- InputEvent(tool_response) -------->|-- continues turn ----------->|
```

- **Phase 1 (Stdio Handshake)**: Hand-rolled protobuf handshake over stdin/stdout exchanges port & authentication key (~200ms).
- **Phase 2 (WebSocket Session)**: Full JSON-over-WebSocket streaming session for turns, tool calls, and event hooks.

---

## 2. Basic Agent Usage

### One-Liner Quick Prompting

```ruby
require 'antigravity'

# Quick 1-line query (auto-connects and closes)
response = Antigravity.ask('What is the square root of 256?')
puts response.content

# 1-line streaming with policy preset
Antigravity.ask('Explain Ruby in 2 sentences', policy: :cautious) do |chunk|
  print chunk.content if chunk.content
end
```

### Standard Chat & Block-based Lifecycle

```ruby
require 'antigravity'

# Automatic connection and teardown with .open
Antigravity::Agent.open(
  model: 'gemini-2.5-flash',
  system_instruction: 'You are a helpful coding assistant.'
) do |agent|
  response = agent.ask('What is the square root of 256?')
  puts response.content
end
```

### Response Streaming

Pass a block to `#ask` to receive real-time text deltas:

```ruby
Antigravity::Agent.open do |agent|
  agent.ask('Explain Ruby blocks in 2 sentences') do |chunk|
    print chunk.content if chunk.content
  end
end
```

---

## 3. Defining Custom Tools

Agents can be equipped with custom Ruby tools using `Antigravity::Tool.define` or by subclassing `Antigravity::Tool`.

```ruby
# Functional DSL definition
weather_tool = Antigravity::Tool.define(:get_weather,
  desc: 'Get current temperature for a city',
  params: {
    city: { type: :string, description: 'Target city name' }
  }
) do |city:|
  "22°C and sunny in #{city}"
end

# Class-based definition
class CalculatorTool < Antigravity::Tool
  name :calculator, desc: 'Evaluates basic mathematical expressions'

  def call(expression:)
    eval(expression).to_s # rubocop:disable Security/Eval
  end
end

# Using tools with an Agent
Antigravity::Agent.open(tools: [weather_tool, CalculatorTool.new]) do |agent|
  puts agent.ask('What is the weather in Milan?').content
end
```

---

## 4. Agent Skills & Progressive Disclosure

Skills extend agent capabilities by bundling system instructions, tools, and domain cheatsheets.

### Constructor & Runtime Skill Attachment

```ruby
# Load local skill folder containing SKILL.md
agent = Antigravity::Agent.new(
  skills: ['./skills/code-quality-review']
)

# Runtime inline skill creation
agent.add_inline_skill(
  name: 'emoji-formatter',
  description: 'Formats findings with severity emojis',
  instructions: 'Prepend 🚨 for CRITICAL and 🔴 for HIGH findings.'
)

# Load additional skill dynamically
agent.add_skill('./skills/security-audit')
```

---

## 5. Security & Execution Policies

Control tool execution and shell safety using built-in or custom policies:

- `:riccardo` — Custom developer policy auto-allowing `gcloud`, `kubectl`, `just`, `rv`, `agc`, protecting `.env` files, and confirming destructive commands.
- `:cautious` — Confirms write tools and destructive operations before execution.
- `:turbo` — Fast mode; auto-allows non-catastrophic shell commands and file operations.
- `:test` — Sandboxed mode for automated testing environments.
- `:auto` — Infers policy based on `RAILS_ENV` or `RACK_ENV`.

```ruby
# Using Riccardo's developer policy preset
Antigravity::Agent.open(policy: :riccardo) do |agent|
  agent.ask('Check gcloud auth and project status')
end

# Importing permissions from Gemini CLI config.json
policy = Antigravity::Policy.from_gemini_config('~/.gemini/config/config.json')

# Exporting any policy to human-readable Ruby DSL string
puts policy.to_ruby_dsl
```

---

## 6. Event Hooks & Observability

Intercept prompts, responses, and tool calls for logging or auditing:

```ruby
agent = Antigravity::Agent.new

agent.before_prompt { |msg| puts "💬 Prompting: #{msg}" }
agent.after_response { |res| puts "🤖 Response received (#{res.usage[:total_token_count]} tokens)" }
agent.before_tool_call { |name, args| puts "🛠️ Executing tool #{name} with #{args.inspect}" }
```

---

## 7. Documentation & Reference Links

For full API documentation, wire protocols, and advanced workflows:
- User Guide: [docs/USER_GUIDE.md](file:///Users/ricc/.gemini/antigravity/worktrees/antigravity-ruby-sdk/fix_ruby_security_findings/docs/USER_GUIDE.md)
- Official Repository: `https://github.com/palladius/antigravity-ruby-sdk`
