# Spec: Declarative Policy DSL

**Track:** policy_dsl_20260814
**Type:** Feature
**GitHub Issue:** #21
**Priority:** P0

## Overview

Add a declarative, Rails-inspired Policy DSL to the Antigravity Ruby SDK. The DSL provides a beautiful, terse, English-like syntax for declaring tool call policies — which tools an agent may use, under what conditions, and when human confirmation is required.

The DSL sits on top of the existing hooks plumbing (`Hooks#before_tool_call` → `:allow`/`:deny` in `hooks.rb`, enforcement in `client.rb:25-32`) and compiles declarative rules into hook callbacks.

## Design (Agreed)

### Core DSL Syntax

```ruby
# Full declarative block:
policy = Antigravity::Policy.define do
  deny_all                                                # wildcard deny
  allow :list_dir                                         # specific allow
  allow :run_command
  deny  :run_command, when: cmd(:rm, 'rm -rf')            # conditional deny
  confirm :create_file, when: path('*.key', 'production.*')  # human gate
  deny :lookup_secret                                     # deny custom tool
end

# One-liner convenience:
policy = Antigravity::Policy.allow_all
policy = Antigravity::Policy.deny_all

# Wire into agent:
agent = Antigravity::Agent.new(policies: [policy])
# OR
agent.enforce(policy)
```

### Rule Types

| Method       | Meaning                                      |
|--------------|----------------------------------------------|
| `allow_all`  | Wildcard allow (every tool passes)            |
| `deny_all`   | Wildcard deny (every tool blocked)            |
| `allow`      | Allow a specific tool (by symbol name)        |
| `deny`       | Deny a specific tool (by symbol name)         |
| `confirm`    | Interactive gate — deny by default if no handler responds |

### Conditional Predicates (Built-in Helpers)

| Helper                   | Purpose                                                    |
|--------------------------|------------------------------------------------------------|
| `cmd(:rm, 'rm -rf')`    | Matches if `command_line` arg contains any of the given strings/symbols |
| `path('*.key', 'prod.*')` | Glob-matches against the file path argument              |
| `args_match(key: /regex/)` | Regex match on any named tool argument                  |

- Predicates are composable — they are Procs/lambdas returned by DSL helper methods.
- Raw lambdas are also accepted: `when: ->(args) { args[:command_line].include?('rm') }`

### Precedence Hierarchy

```
Specific Deny > Specific Confirm > Specific Allow > Wildcard Deny > Wildcard Confirm > Wildcard Allow
```

When multiple rules match a tool call, the **most restrictive specific rule** wins. Wildcards only apply when no specific rule matches.

### `confirm` Behavior

- `confirm` rules invoke an optional handler (block or Proc).
- Handler receives a tool call context hash `{ name:, args: }` and returns `true` (approve) or `false` (deny).
- **Default behavior**: if no handler is wired, `confirm` acts as **deny** (fail-closed).
- A global `on_confirm` handler can be set: `policy.on_confirm { |ctx| ... }`

### Agent Integration

- `Agent.new(policies: [...])` — accepts an array of Policy objects.
- `agent.enforce(policy)` — attach a policy after construction.
- Policies compile into `before_tool_call` hooks; no changes needed to `Client#execute_tool`.

## Functional Requirements

1. `Antigravity::Policy.define { ... }` returns a `Policy` object containing ordered rules.
2. `Policy#evaluate(tool_name, args)` returns `{ decision: :allow | :deny | :confirm, reason: String }`.
3. Built-in helpers (`cmd`, `path`, `args_match`) return Proc predicates.
4. `Policy.allow_all` / `Policy.deny_all` return single-rule policy objects.
5. Policies wire into `Agent` via `before_tool_call` hooks transparently.
6. Named policies: `deny :run_command, when: cmd(:rm), name: 'block-rm'` — `name:` is optional, used in deny reasons.

## Acceptance Criteria (from GHI #21 / Python example)

1. `list_dir` — **allowed** (explicitly in allowlist)
2. `rm -rf` — **denied** (predicate matches `rm` in command_line)
3. `production.key` creation — triggers **confirm** → denied (handler returns false)
4. Custom tool `lookup_secret` — **denied** by name

## Non-Functional Requirements

- Pure Ruby, no external dependencies.
- Thread-safe (frozen rule sets after `define`).
- `#frozen_string_literal: true` header on all files.
- RSpec tests with >80% coverage.

## Out of Scope

- Policy serialization (YAML/JSON config files) — future track.
- Network-based policy servers — future track.
- `workspace_only(paths)` convenience (mentioned in GHI #21 but deferred — can be composed from `path()`).
