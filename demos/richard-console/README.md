# Richard Console Demo (REAL)

**This is the real deal.** VHS drives the actual Antigravity console with a live Gemini API connection.

## What it shows

1. **LLM Chat** — asks a question, gets a real (non-deterministic) response
2. **Shell exec** — `! pwd` runs in your terminal
3. **Ruby eval** — `r! Antigravity::VERSION` and `r! RUBY_VERSION`
4. **Matrix /irb mode** — 💊 red pill entry, real Ruby eval:
   - `config` — full agent configuration hash (pp output)
   - `config.select { |k,_| [:version, :workspace, :model].include?(k) }` — Ruby power!
   - `Antigravity::Policy::SAFE_CMDS` — allowed shell commands
   - `Antigravity::Policy::CATASTROPHIC_CMDS` — hard-denied commands
   - `cd`, `set_policy` — smart setters that propagate to the running agent
   - `exit` — "Welcome to the real world, Neo." 🕶️

## Record it

```bash
cd ~/git/antigravity-ruby-sdk && vhs demos/richard-console/demo.tape
```

> **Note**: Requires a valid `GEMINI_API_KEY` and the Go localharness binary.
> LLM responses will vary each time — that's the beauty of it!

## Files

| File | Description |
|------|-------------|
| `demo.tape` | VHS tape configuration |
| `demo.gif` | Animated GIF (used in README.md) |
| `demo.mp4` | MP4 video |
