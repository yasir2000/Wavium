# ADR 003: Capability Security

Status: Accepted

Wavium uses capability-based security to avoid ambient authority and to make every privileged action explicit.

## Consequences

- resource access is auditable
- device and runtime access are mediated
- least privilege becomes a platform default
- runtime and hardware policy can be reviewed independently of component code