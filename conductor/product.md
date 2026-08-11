# Antigravity Ruby SDK

## Vision

An elegant, expressive Ruby SDK for building autonomous AI agents powered by Google Antigravity. Inspired by the philosophy of RubyLLM, it provides a beautiful Ruby-native interface to the Antigravity harness — making agent creation, skill loading, tool registration, and multi-turn conversations feel natural and idiomatic.

## Description

The Antigravity Ruby SDK (`antigravity-sdk` gem) enables Ruby developers to:

- **Create AI agents** with streaming/non-streaming responses and multi-turn chat
- **Load and manage skills** from local directories, GitHub repositories, or inline definitions
- **Register custom tools** that the LLM can invoke during conversation
- **Analyze workspaces** with built-in filesystem exploration tools
- **Guard agent behavior** with safety rails (file protection, secret masking)
- **Observe agent activity** via telemetry sidecars (audit logging, stats)
- **Build integrations** like Telegram bots with voice transcription support

## Target Audience

- Ruby developers building AI-powered applications
- DevOps/SRE teams creating agent-based automation
- Developers who want a RubyLLM-like experience for the Antigravity platform

## Core Principles

1. **Ruby-native elegance**: Block syntax, method chaining, convention over configuration
2. **Zero-install**: Works via `rv run ruby` without gem installation
3. **Safety-first**: Built-in guards prevent unsafe file access and secret leakage
4. **Extensible**: Skills, tools, hooks, and sidecars are all pluggable
