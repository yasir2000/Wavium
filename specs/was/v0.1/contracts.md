# Wavium Architecture Specification (WAS) v0.1 - Contracts

## Ownership and Lifecycle
- RuntimeContext owns service registry lifecycle.
- Module-local allocators must be explicit function parameters or struct fields.
- Component instances are isolated units and may not share mutable state.

## Failure Semantics
- Initialization must fail fast on invalid config.
- Authorization failures return explicit errors, never silent fallback.
- Backpressure conditions must be surfaced to callers.

## Compatibility
- WIT interface changes require version bump.
- Canonical ABI mapping rules must be deterministic and test-covered.
