# 💎 Antigravity Ruby SDK (`antigravity-sdk`)

An elegant, expressive, and human-friendly Ruby SDK for building autonomous AI agents with **Google Antigravity**.

Inspired by the Ruby community's philosophy of developer happiness and standard conventions (such as `RubyLLM`), `antigravity-sdk` lets you configure agents, stream thoughts & token deltas, invoke declarative/dynamic tools, and chain pre/post lifecycle hooks with minimal boilerplate.

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

## 🪝 Lifecycle Hooks & Tools

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

agent = Antigravity::Agent.new do |a|
  # Register declarative & dynamic tools
  a.register_tool(WeatherTool.new)
  a.register_tool("calculator", description: "Evaluates expressions") { |params| 42 }

  # Pre-prompt and post-response hooks
  a.before_prompt { |prompt| puts "Sending: #{prompt}" }
  a.after_response { |msg| puts "Finished turn with #{msg.model_id}" }
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
```

---

## 📄 License

Apache 2.0 - see `LICENSE` for details.
