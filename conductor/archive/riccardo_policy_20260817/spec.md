# Specification: Riccardo Policy DSL & Gemini Config Importer

## Overview
Implement `Policy.preset(:riccardo)`, `Policy.from_gemini_config(path)`, and `Policy#to_ruby_dsl`. This allows importing existing Gemini CLI auto-approved permissions from `~/.gemini/config/config.json`, executing with Riccardo's personal policy preset, and exporting policies as clean, human-readable Ruby DSL code for blogging and documentation.

## Functional Requirements
1. **`Policy.preset(:riccardo)` / `Policy.riccardo`**:
   - Curated policy preset for Riccardo's workflow.
   - Allows safe dev commands (`gcloud`, `kubectl`, `just`, `rv`, `npx skills`, `agc`, `chezmoi`).
   - Protects sensitive paths (`.env`, `~/.ssh`, `~/.aws`, `~/.config/gcloud`).
   - Confirms destructive git commands (`git push --force`, `git reset --hard`) and destructive deletes (`rm -rf`).
2. **`Policy.from_gemini_config(file_path)`**:
   - Reads a Gemini CLI `config.json` file.
   - Extracts auto-approved permissions (`unsandboxed(...)`, `command(...)`, `read_file(...)`, `write_file(...)`, `mcp(...)`).
   - Translates JSON permissions into a clean `Antigravity::Policy`.
3. **`Policy#to_ruby_dsl`**:
   - Serializes any `Policy` instance into valid, formatted Ruby DSL string output (`Policy.define do ... end`).
4. **Documentation & Tests**:
   - Document in `docs/USER_GUIDE.md` and `skills/using-antigravity-ruby-sdk/SKILL.md`.
   - Comprehensive unit test coverage in `spec/antigravity/riccardo_policy_spec.rb`.

## Acceptance Criteria
- `Policy.preset(:riccardo)` works out of the box.
- `Policy.from_gemini_config` correctly imports permissions from `~/.gemini/config/config.json`.
- `Policy#to_ruby_dsl` generates valid Ruby code.
- All RSpec unit tests pass cleanly (`just test`).
