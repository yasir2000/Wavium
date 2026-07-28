# Design Philosophy

Wavium follows a strict separation between application logic, runtime services, and hardware control.

The design philosophy is intentionally infrastructure-grade:
- no hidden authority
- no ambient OS services
- no implicit allocation paths
- no text-first internal protocol assumptions
- no coupling to any single CPU or board family

## Design Tenets

1. Make the component boundary the default execution unit.
2. Prefer explicit contracts over inferred behavior.
3. Treat hardware access as a mediated capability.
4. Keep runtime state observable and recoverable.
5. Keep the system small enough to reason about at boot and at failure time.

## Architectural Consequences

- the runtime owns lifecycle and trust policy
- WIT defines the stable external API surface
- the HAL and bootloader are part of the platform, not helper utilities
- docs and tests must evolve with the code

The platform is meant to be auditable, portable, and small enough to run on hardware where a conventional cloud stack would be inappropriate.

## Related Documentation

- [Project Vision](project-vision.md)
- [Why Wavium](why-wavium.md)
- [Architecture Overview](../architecture/overview.md)
- [Security Model](../architecture/security-model.md)