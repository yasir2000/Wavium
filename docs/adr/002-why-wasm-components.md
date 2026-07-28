# ADR 002: Why WASM Components

Status: Accepted

WASM Components are the primary execution boundary because they provide portability, isolation, and a stable interface model across language ecosystems.

## Consequences

- language-neutral applications
- explicit component contracts
- portable execution across supported hardware targets
- a cleaner path to SDK generation and verification

## Related Documentation

- [Component Model](../architecture/component-model.md)
- [Wavium Component Spec](../specifications/wavium-component-spec.md)