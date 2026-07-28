# Wavium Security Specification

Wavium security is built around capability tokens, sandboxed execution, and signed artifacts.

## The Specification Covers

- authorization boundaries
- trust anchors
- package signing
- secure boot
- threat modeling

## Security Posture

- deny by default
- grant only the capabilities required for the task
- keep audit paths explicit and reviewable

## Related Documentation

- [Security Model](../architecture/security-model.md)
- [ADR 003: Capability Security](../adr/003-capability-security.md)
- [Wavium Hardware Spec](wavium-hardware-spec.md)