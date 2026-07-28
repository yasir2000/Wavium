# Package Format

Wavium packages are designed to carry component bytes, metadata, capabilities, and trust material together.

## Package Contents

- a versioned header
- metadata and dependencies
- component payloads
- capability declarations
- signatures or trust references

## Lifecycle

source -> compile -> package -> sign -> verify -> deploy

Package structure must remain stable enough to support long-term tooling and reproducible deployment.

## Related Documentation

- [Build System](build-system.md)
- [Wavium Component Spec](../specifications/wavium-component-spec.md)
- [Wavium Security Spec](../specifications/wavium-security-spec.md)