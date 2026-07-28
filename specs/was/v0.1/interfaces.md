# Wavium Architecture Specification (WAS) v0.1 - Interfaces

## Core Contracts
- wavium-core:
  - init(config) -> RuntimeContext
  - start(ctx) -> void
  - shutdown(ctx) -> void

- wavium-memory:
  - arena.alloc(size, alignment) -> []u8
  - arena.reset() -> void
  - quota.reserve(size) -> error!void

- wavium-scheduler:
  - submit(task) -> error!void
  - runOne() -> bool
  - runUntilEmpty() -> usize

- wavium-security:
  - issue(subject_id, permissions) -> CapabilityToken
  - authorize(token, permission) -> bool

## Cross-Module Constraints
- Every resource access path must include capability authorization.
- Scheduler task closures must never perform hidden allocations by default.
- WIT-generated interfaces are the only stable external API surface.
