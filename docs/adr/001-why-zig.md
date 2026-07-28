# ADR 001: Why Zig

Status: Accepted

Wavium uses Zig for the core platform because it supports freestanding builds, explicit memory control, and low-level systems programming without depending on a runtime-heavy language stack.

## Consequences

- deterministic control over boot and runtime behavior
- simpler freestanding compilation
- a single implementation language for the core platform
- predictable cross-compilation for hardware-oriented targets

## Related Documentation

- [ADR 004: No OS Design](004-no-os-design.md)
- [Architecture Overview](../architecture/overview.md)