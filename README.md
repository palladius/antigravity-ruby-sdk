# 💎 Antigravity Ruby SDK (`antigravity-sdk`)

<p align="center">
  <img src="docs/images/logo.jpg" alt="Ruby Antigravity Logo" width="350"/>
</p>

An elegant, expressive, and human-friendly Ruby SDK for building autonomous AI agents with **Google Antigravity**.

Inspired by the Ruby community's philosophy of developer happiness and standard conventions (such as `RubyLLM`), `antigravity-sdk` lets you configure agents, stream thoughts & token deltas, invoke declarative/dynamic tools, manage async sidecars, and enforce safety guardrails with minimal boilerplate.

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

# Create an agent with reflective block configuration
agent = Antigravity::Agent.new(model: "gemini-2.5-flash") do |a|
  a.system_instruction = "You are a helpful Ruby assistant."
end

# Stream responses cleanly with block semantics
agent.ask("Why do developers love Ruby?") do |chunk|
  print chunk.content if chunk.content
end
```

---

## 🛡️ Safety Guardrails & Sidecars

```ruby
class WeatherTool
  include Antigravity::Tool
  tool_name "get_weather"
  tool_description "Retrieves weather report"
  param :city, type: :string, description: "City name"

  def call(city:)
    "Sunny in #{city}"
  end
end

# Attach Audit Logger Sidecar
audit_logger = Antigravity::Sidecar::AuditLogger.new("log/agent_audit.jsonl")

agent = Antigravity::Agent.new do |a|
  # Register declarative & dynamic tools
  a.register_tool(WeatherTool.new)
  a.attach_sidecar(audit_logger)

  # Pre-tool safety policy against modifying .env or Gemfile
  a.before_tool_call(&Antigravity::Safety::ProtectedFilesGuard.new)

  # Post-tool secret masker
  a.after_tool_call(&Antigravity::Safety::SecretMasker.new)
end

# Ask agent
message = agent.ask("Check get_weather in Rome") do |chunk|
  puts "[Thought] #{chunk.thinking}" if chunk.thinking
  print chunk.content if chunk.content
end
```

---

## 🧪 Running Examples & Tests

Run the full RSpec test suite:

```bash
bundle exec rake spec
```

Run example scripts:

```bash
bundle exec ruby examples/01_hello_world.rb
bundle exec ruby examples/02_e2e_advanced_agent.rb
bundle exec ruby examples/03_e2e_safety_and_sidecar.rb
```

---

## 📄 License

Apache 2.0 - see `LICENSE` for details.
