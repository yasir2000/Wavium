# ADR 001: Why Zig

Status: Accepted

Wavium uses Zig for the core platform because it supports freestanding builds, explicit memory control, and low-level systems programming without depending on a runtime-heavy language stack.

Consequences:
- deterministic control over boot and runtime behavior
- simpler freestanding compilation
- a single implementation language for the core platform