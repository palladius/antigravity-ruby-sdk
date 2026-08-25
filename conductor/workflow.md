# Workflow

## Development Process
1. **TDD is mandatory**: Start with failing tests, then implement.
2. **Version bumps**: Update VERSION + CHANGELOG.md for every release.
3. **Commit style**: Use gitmoji in commit messages, single-quote `-m`.
4. **Testing**: `just test` before every commit. Target: >90% coverage.

## Commit Frequency
- Commit after each completed phase/task.
- One logical change per commit.

## Quality Gates
- All unit tests pass (`just test`)
- No Rubocop violations (`bundle exec rubocop`)
- CHANGELOG.md updated
- VERSION bumped for releases
