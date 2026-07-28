# Wavium Architecture Specification (WAS) v0.1 - Layers

## Layer Model
1. Hardware Substrate
- Physical compute and I/O foundation: CPU, memory, storage, network, timers, interrupts, optional accelerators.

2. Hardware Abstraction Layer (wavium-hal)
- First-class Wavium Hardware Abstraction Layer (W-HAL).
- Resource discovery, device capability mediation, and board-specific initialization.
- Exposes hardware only through typed capabilities and driver-owned handles.

3. Hardware Discovery and Driver Plane
- Device discovery, registry, driver components, and vendor-facing hardware SDK hooks.
- Supports device tree, ACPI, PCI, and embedded board manifests.

4. Runtime Foundation (wavium-core, wavium-memory, wavium-scheduler, wavium-security)
- Lifecycle, deterministic memory, cooperative execution, capability checks.

5. Component Execution (wavium-wasm, wavium-component, wavium-wit, wavium-wasi)
- WASM load/validate/instantiate/execute and WIT contract enforcement.

6. Actor and State Plane (wavium-actor, wavium-fabric, wavium-state)
- Actor lifecycle, binary messaging fabric, durable state.

7. Federation and Tooling (wavium-federation, wavium-cli, wavium-sdk)
- Multi-node coordination and developer workflows.

## Hard Rule
Higher layers may depend on lower layers; lower layers must not depend on higher layers.
