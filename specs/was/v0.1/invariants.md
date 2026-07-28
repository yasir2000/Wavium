# Wavium Architecture Specification (WAS) v0.1 - Invariants

## Security Invariants
- No ambient authority.
- All privileged actions require explicit capability token.

## Memory Invariants
- No implicit global allocator dependency.
- Deterministic allocator behavior under equal input sequence.
- Quota breaches fail explicitly.

## Scheduler Invariants
- Cooperative execution only in v0.1.
- No shared mutable state between isolated actor/component contexts.

## Data Plane Invariants
- Internal communication uses binary payloads.
- No JSON/REST/HTTP in runtime internal fabric.
