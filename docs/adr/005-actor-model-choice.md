# ADR 005: Actor Model Choice

Status: Accepted

Wavium uses actors to structure concurrency because actors isolate state and give the runtime a clear scheduling and supervision boundary.

Consequences:
- mailbox-driven communication
- reduced shared-state complexity
- better failure containment and replay semantics