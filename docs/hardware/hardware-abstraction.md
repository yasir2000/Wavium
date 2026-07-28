# Hardware Abstraction

The hardware abstraction layer exposes devices through typed capabilities rather than OS device files.

## Responsibilities

- safe device access
- board-specific initialization
- capability mediation
- driver ownership boundaries
- stable interface surfaces for hardware-facing components

## Design Rules

- do not expose ambient device files
- keep hardware interactions explicit and typed
- retain a clear ownership boundary between runtime and driver
- preserve deterministic access paths for boot and runtime

The HAL is the policy boundary between physical devices and component-level execution.

## Related Documentation

- [Bootloader](bootloader.md)
- [Device Model](device-model.md)
- [Driver Framework](driver-framework.md)