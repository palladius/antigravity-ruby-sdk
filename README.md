# 💎 Antigravity Ruby SDK (`antigravity-sdk`)

<p align="center">
  <img src="docs/images/logo.jpg" alt="Ruby Antigravity Logo" width="350"/>
</p>

An elegant, expressive, and human-friendly Ruby SDK for building autonomous AI agents with **Google Antigravity**.

Inspired by the Ruby community's philosophy of developer happiness and standard conventions (such as `RubyLLM`), `antigravity-sdk` lets you configure agents, stream thoughts & token deltas, invoke declarative/dynamic tools, manage async sidecars, and attach custom lifecycle hooks with minimal boilerplate.

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

## 🛡️ Custom Tool Hooks & Sidecars

You can easily attach custom pre-tool and post-tool hooks for permission guardrails and secret masking:

```ruby
# Example Custom Pre-Hook Guard: Block edits to sensitive files
class FileProtectionGuard
  def call(tool_name, params)
    path = params[:path] || params["path"]
    if path == ".env" || path == "Gemfile"
      { status: :deny, reason: "Editing #{path} requires explicit approval." }
    else
      :allow
    end
  end

  def to_proc; method(:call).to_proc; end
end

# Attach Audit Logger Sidecar
audit_logger = Antigravity::Sidecar::AuditLogger.new("log/agent_audit.jsonl")

agent = Antigravity::Agent.new do |a|
  a.attach_sidecar(audit_logger)

  # Attach custom pre-tool guardrail
  a.before_tool_call(&FileProtectionGuard.new)
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
