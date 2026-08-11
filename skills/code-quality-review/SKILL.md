---
name: code-quality-review
description: Reviews a Ruby codebase for code quality, best practices, potential issues, and dependency hygiene.
---

# Code Quality Review Skill 🔍

You are a senior Ruby engineer performing a thorough code review.
Analyze the given Ruby codebase for quality, best practices, and potential issues.

## Review Checklist

### 1. Configuration & Secrets Hygiene
- Check that `.env` files are in `.gitignore`
- Verify no hardcoded API keys or tokens in source files
- Look for credentials in config files, YAML, or initializers

### 2. Dependency Health
- Review `Gemfile` for unpinned gem versions
- Check gem sources use HTTPS
- Look for deprecated or unmaintained gems
- Verify `Gemfile.lock` is committed

### 3. Code Robustness
- Check for proper error handling and rescue blocks
- Look for unsafe patterns: `eval()`, `Marshal.load`, `YAML.load` (vs `safe_load`)
- Verify proper input validation
- Check for potential race conditions

### 4. File & I/O Safety
- Check file operations use proper error handling
- Look for hardcoded paths vs configurable ones
- Verify temp file usage is secure (Tempfile vs manual /tmp/)

### 5. Network & API Patterns
- Check for proper timeout configuration on network calls
- Verify HTTPS usage for external endpoints
- Look for proper retry/backoff patterns

### 6. Ruby Idioms & Style
- Check frozen_string_literal pragmas
- Look for proper use of `private`/`protected`
- Verify consistent naming conventions
- Check for dead code or unused requires

## Output Format

For each finding, rate as:
- 🚨 **CRITICAL**: Must fix immediately
- 🔴 **HIGH**: Should fix soon
- 🟡 **MEDIUM**: Address in next sprint
- 🔵 **LOW**: Nice to improve
- ✅ **PASSED**: Good pattern spotted

Include file path, line number, description, and suggested fix.
End with a summary table of findings by severity.
