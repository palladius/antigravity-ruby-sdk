# Product Definition: Antigravity Ruby SDK

## Vision
A Ruby gem (`antigravity-sdk`) that provides first-class Ruby access to Google's Antigravity AI agent harness. Think of it as the Ruby equivalent of the official Python SDK, but idiomatic and Rubyish.

## Core Value Proposition
- **Zero-install agent runtime** via `rv run` (like `uv run` for Python)
- **Lifecycle hooks** for observability (session, turn, tool, indexing events)
- **Tool framework** with DSL-style `class MyTool < Antigravity::Tool`
- **Skill system** for loading agent capabilities from local/remote sources
- **Streaming** with thinking token support
- **Jevity decision harness & guardrails** (`bin/jevity`, `bin/rujev`) with JEV System One routing and safe command gating

## Target Users
- Ruby developers building AI agents
- DevRel/SRE teams wanting Ruby-native AI tooling
- Developers who prefer Ruby's expressiveness over Python

## Current State (v0.7.0)
Working: agent lifecycle, hooks, tools, skills, E2E tests, diagnostics, workspace indexing, thinking console REPL, Jevity decision & guardrail harness.
Missing: TUI module, MCP support.
