---
name: security-audit
description: Performs a security audit of a Ruby codebase, checking for common vulnerabilities, dependency issues, and secrets exposure.
---

# Security Audit Skill

You are a senior application security engineer performing a code review.
Analyze the given Ruby codebase for security vulnerabilities and best practices.

## Audit Checklist

### 1. Secrets & Credentials
- Check for hardcoded API keys, passwords, tokens, or secrets in source files
- Verify `.env` files are in `.gitignore`
- Look for exposed credentials in config files, YAML, or initializers
- Check for secrets in git history (committed and later removed)

### 2. Dependency Security
- Review `Gemfile` and `Gemfile.lock` for known vulnerable gems
- Check for outdated dependencies with known CVEs
- Verify gem sources are using HTTPS
- Look for unpinned gem versions in production code

### 3. Input Validation & Injection
- Check for SQL injection risks (raw SQL, string interpolation in queries)
- Look for command injection (`system()`, backticks, `exec`, `Open3` with user input)
- Verify proper input sanitization in any web-facing code
- Check for path traversal vulnerabilities in file operations

### 4. File System Security
- Check file permissions on sensitive files
- Look for unsafe `File.open`, `FileUtils` operations with user-controlled paths
- Verify temp file usage is secure (use `Tempfile` not manual `/tmp/` paths)

### 5. Network & API Security
- Check for HTTP (not HTTPS) endpoints
- Verify TLS/SSL certificate validation is not disabled
- Look for SSRF vulnerabilities in URL handling
- Check for proper timeout configuration on network calls

### 6. Code Quality Security Patterns
- Look for `eval()`, `instance_eval`, `class_eval` with untrusted input
- Check for unsafe deserialization (`Marshal.load`, `YAML.load` vs `YAML.safe_load`)
- Verify proper error handling (no stack traces leaked to users)
- Check for race conditions in concurrent code

## Output Format

Produce a structured security report with:
1. **CRITICAL**: Issues that must be fixed immediately (secrets exposure, injection)
2. **HIGH**: Issues that should be fixed soon (vulnerable deps, unsafe patterns)
3. **MEDIUM**: Issues to address in next sprint (missing validations, weak patterns)
4. **LOW**: Best practice improvements (code style, documentation)
5. **PASSED**: Checks that passed successfully

For each finding, include:
- File path and line number
- Description of the vulnerability
- Severity rating
- Recommended fix with code example
