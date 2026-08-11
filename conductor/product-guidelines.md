# Product Guidelines

## Voice & Tone

- **Technical but approachable**: Documentation reads like a senior Ruby developer explaining to a peer
- **Concise**: Prefer code examples over prose
- **Opinionated**: Follow Ruby conventions and the "Omakase" philosophy

## Code Style

- Follow RuboCop defaults with minor project-specific overrides
- Use block syntax (`Agent.open { |a| ... }`) as the primary API pattern
- Prefer keyword arguments for configuration
- Use `snake_case` for methods, `CamelCase` for classes

## UX Principles

- **Sensible defaults**: Everything should work with minimal configuration
- **Progressive disclosure**: Simple things are simple, complex things are possible
- **Fail loudly**: Clear error messages with actionable guidance
