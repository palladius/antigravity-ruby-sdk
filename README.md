# 💎 Antigravity Ruby SDK (`antigravity-sdk`)

<p align="center">
  <img src="docs/images/logo.jpg" alt="Ruby Antigravity Logo" width="350"/>
</p>

An elegant, expressive, and human-friendly Ruby SDK for building autonomous AI agents with **Google Antigravity**.

Inspired by the Ruby community's philosophy of developer happiness and standard conventions (such as `RubyLLM`), `antigravity-sdk` lets you configure agents, stream thoughts & token deltas, invoke declarative/dynamic tools, manage async sidecars, and attach opt-in safety guards with minimal boilerplate.

---

## 📦 Installation

Add `antigravity-sdk` to your `Gemfile`:

```ruby
gem "antigravity-sdk"
```

Or install manually:

```bash
gem install antigravity-sdk
```

---

## ⚡ Quickstart

```ruby
require "antigravity"

# Create an agent with sensible defaults (model defaults to "gemini-flash-latest")
agent = Antigravity::Agent.new do |a|
  a.system_instruction = "You are a helpful Ruby assistant."
end

# Stream responses cleanly with block semantics
agent.ask("Why do developers love Ruby?") do |chunk|
  print chunk.content if chunk.content
end
```

---

## 🛡️ Opt-In Configurable Guards & Sidecars

`antigravity-sdk` ships with opt-in guard helpers like `Antigravity::Guards::FileProtection` and `Antigravity::Guards::SecretMasker`:

```ruby
# Configurable file protection guard (pass custom files, or use defaults)
file_guard = Antigravity::Guards::FileProtection.new(files: [".env", "Gemfile", "config/database.yml"])
secret_masker = Antigravity::Guards::SecretMasker.new

# Attach Audit Logger Sidecar
audit_logger = Antigravity::Sidecar::AuditLogger.new("log/agent_audit.jsonl")

agent = Antigravity::Agent.new do |a|
  a.attach_sidecar(audit_logger)

  # Explicitly attach configurable guards
  a.before_tool_call(&file_guard)
  a.after_tool_call(&secret_masker)
end

# Ask agent
message = agent.ask("Check weather in Rome") do |chunk|
  puts "[Thought] #{chunk.thinking}" if chunk.thinking
  print chunk.content if chunk.content
end
```

---

## 🧪 Running Examples & Tests

Run the full RSpec test suite:

```bash
just test
```

Run example scripts:

```bash
just examples
```

---

## 📄 License

Apache 2.0 - see `LICENSE` for details.
