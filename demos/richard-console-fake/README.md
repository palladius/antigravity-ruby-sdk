# Richard Console Demo (SIMULATED)

> **This is a simulated demo.** Commands are scripted for demonstration purposes.
> For the real thing, see [`demos/richard-console/`](../richard-console/).

## Why a fake demo?

The real demo requires a Gemini API key and network connection. This fake version
uses a Ruby script that prints pre-scripted output with realistic ANSI colors
and timing — useful for offline recordings or when you need deterministic output.

## Record it

```bash
cd ~/git/antigravity-ruby-sdk && vhs demos/richard-console-fake/demo.tape
```

## Files

| File | Description |
|------|-------------|
| `demo.rb` | Ruby script that simulates the console |
| `demo.tape` | VHS tape that runs the script |
| `demo.gif` | Animated GIF output |
| `demo.mp4` | MP4 video output |
