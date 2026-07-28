# Contributing to Wavium

Wavium follows an architecture-first, specification-driven workflow.

## Development Workflow
1. Read the relevant documentation under [docs](docs) before changing code.
2. Prefer small, reviewable changes tied to a specific subsystem or spec.
3. Run `sh scripts/ci.sh` before opening a pull request.
4. Update docs, tests, and architecture notes together when behavior changes.

## Coding Standards
- Zig code must remain freestanding-friendly and explicit about ownership.
- Avoid hidden allocation, implicit globals, and OS-specific assumptions.
- Keep public APIs deterministic and test-covered.
- Match existing naming and module boundaries.

## Pull Requests
- Describe the subsystem, the behavior change, and the validation performed.
- Link to the relevant docs or architecture note.
- Include screenshots or diagrams when the change affects documentation or flows.

## Review Process
- Reviews should check for correctness, architectural alignment, and test coverage.
- Security-sensitive changes require a clear threat model and mitigation note.

## Testing Requirements
- Run the full workspace CI wrapper before requesting review.
- Add focused tests for new runtime, hardware, or toolchain behavior.
- If a change affects docs only, update the relevant documentation index page.