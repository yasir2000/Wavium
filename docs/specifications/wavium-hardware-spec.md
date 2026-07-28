# Wavium Hardware Specification

This specification defines the bootloader, HAL, discovery, driver, and board support expectations for Wavium.

## It Should Cover

- reset-to-runtime handoff
- architecture-specific bring-up
- device capability mapping
- supported platforms
- simulator compatibility

## Hardware Contract

Hardware support must be expressed as capabilities and manifests rather than as ambient OS device access.

## Related Documentation

- [Hardware Architecture](../architecture/hardware-architecture.md)
- [Bootloader](../hardware/bootloader.md)
- [Wavium Security Spec](wavium-security-spec.md)