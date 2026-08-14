# Plan: Declarative Policy DSL

**Track:** policy_dsl_20260814
**Spec:** [spec.md](./spec.md)

---

## Phase 1: Core Policy Engine (Red → Green → Refactor)

- [ ] Task: Write failing RSpec tests for `Antigravity::Policy` (`spec/antigravity/policy_spec.rb`)
  - [ ] Test `Policy.define { deny_all }` creates a policy with one wildcard deny rule
  - [ ] Test `Policy.define { allow_all }` creates a policy with one wildcard allow rule
  - [ ] Test `Policy.allow_all` convenience constructor
  - [ ] Test `Policy.deny_all` convenience constructor
  - [ ] Test `allow :list_dir` creates a specific allow rule
  - [ ] Test `deny :run_command` creates a specific deny rule
  - [ ] Test `deny :run_command, when: <predicate>` creates a conditional deny rule
  - [ ] Test `confirm :create_file` creates a confirm rule (default: deny)
  - [ ] Test `confirm :create_file, when: <predicate>` creates a conditional confirm rule
  - [ ] Test `Policy#evaluate(tool_name, args)` returns correct decisions
  - [ ] Test precedence: Specific Deny > Specific Confirm > Specific Allow > Wildcard Deny > Wildcard Allow
  - [ ] Test named rules: `deny :tool, name: 'block-rm'` includes name in reason
  - [ ] Test rule freezing after `define` (immutability)

- [ ] Task: Implement `lib/antigravity/policy.rb`
  - [ ] `Policy.define(&block)` — DSL evaluation via `instance_eval`
  - [ ] `Policy.allow_all` / `Policy.deny_all` class-level constructors
  - [ ] `Rule` value object: `type`, `tool`, `predicate`, `name`, `handler`
  - [ ] `#allow`, `#deny`, `#deny_all`, `#allow_all`, `#confirm` DSL methods
  - [ ] `#evaluate(tool_name, args)` — rule matching with precedence
  - [ ] Freeze rules after `define` block completes

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 2: Built-in Predicate Helpers (Red → Green → Refactor)

- [ ] Task: Write failing RSpec tests for predicate helpers (`spec/antigravity/policy_spec.rb`)
  - [ ] Test `cmd(:rm)` matches when `command_line` arg contains `rm`
  - [ ] Test `cmd(:rm, 'rm -rf')` matches any of multiple patterns
  - [ ] Test `cmd(:rm)` does NOT match `echo "rm is dangerous"`... wait, it should! It's substring match
  - [ ] Test `cmd` accepts both symbols and strings
  - [ ] Test `path('*.key')` matches `production.key` but not `readme.md`
  - [ ] Test `path('*.key', 'production.*')` matches either glob
  - [ ] Test `path` checks multiple arg keys: `:path`, `:file`, `:target`, `:file_path`
  - [ ] Test `args_match(command_line: /rm/)` matches regex against named arg
  - [ ] Test raw lambda predicates: `when: ->(args) { ... }` still work

- [ ] Task: Implement predicate helpers in `lib/antigravity/policy.rb`
  - [ ] `cmd(*patterns)` — returns Proc that checks `command_line` / `CommandLine` arg
  - [ ] `path(*globs)` — returns Proc that glob-matches path-like args
  - [ ] `args_match(**matchers)` — returns Proc that regex-matches named args
  - [ ] All helpers return frozen Procs for thread safety

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 3: Agent Integration (Red → Green → Refactor)

- [ ] Task: Write failing RSpec tests for Agent integration (`spec/antigravity/policy_integration_spec.rb`)
  - [ ] Test `Agent.new(policies: [policy])` wires policy into `before_tool_call` hooks
  - [ ] Test `agent.enforce(policy)` attaches policy after construction
  - [ ] Test multiple policies are evaluated in order (array semantics)
  - [ ] Test tool execution is blocked when policy denies
  - [ ] Test tool execution proceeds when policy allows
  - [ ] Test `confirm` triggers handler and respects its return value

- [ ] Task: Integrate Policy into `Agent` and `Client`
  - [ ] Add `policies:` kwarg to `Agent#initialize`
  - [ ] Add `Agent#enforce(policy)` method
  - [ ] Wire `Policy#evaluate` into `Hooks#before_tool_call` chain
  - [ ] Ensure backward compatibility — no `policies:` = current behavior

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 4: E2E Example & Documentation (Red → Green → Refactor)

- [ ] Task: Create `examples/10_e2e_policies.rb`
  - [ ] Define a policy matching the 4 acceptance criteria from GHI #21
  - [ ] Register a custom `lookup_secret` tool
  - [ ] Run 4 prompts demonstrating: allow, deny, confirm→deny, deny-custom-tool
  - [ ] Print clear output showing each decision

- [ ] Task: Update `CHANGELOG.md` with Policy DSL entry
- [ ] Task: Update `README.md` with Policy DSL section (if applicable)
- [ ] Task: Update `conductor/tech-stack.md` with `policy.rb` entry

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 5: Review Fixes (reserved)

*This phase is reserved for corrections identified during code review.*
