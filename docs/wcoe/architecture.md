# WCOE Architecture Blueprint

## 1. Mission
WCOE (WebAssembly Cloud Operating Environment) is a bare-metal, WebAssembly-native execution platform written primarily in Zig.

Primary goals:
- Run WebAssembly components directly with capability-based isolation.
- Avoid dependency on Linux, POSIX, libc, ELF, containers, and OS process boundaries.
- Deliver deterministic performance and ultra-small footprint for edge and cloud.

## 1.1 Technical Identity
- Wavium is an execution substrate, not a container orchestrator or VM abstraction.
- The stable application boundary is WIT over the WebAssembly Component Model.
- Internal runtime communication is binary-first and capability-gated by default.

Canonical stack:
- Application -> WASM Component -> WIT Contracts -> Wavium Runtime -> Hardware

Boot chain:
- Hardware Reset -> Wavium Bootloader -> Hardware Init -> Runtime Loader -> Core Runtime -> WASM Component World

## 2. Engineering Principles
- Component-first execution: all workloads are WASM components.
- Capability-first security: no ambient authority.
- Binary-first communication: no JSON/HTTP in the internal data plane.
- Deterministic memory and scheduling: bounded, explicit, predictable.
- Explicit ownership: no hidden allocation and no implicit global state.
- Progressive backends: interpreter first, then JIT/AOT when profiling proves value.
- Hardware-aware abstraction: expose resources through WIT interfaces.
- Firmware-first startup: bootloader ownership begins at the reset vector and ends when the runtime is handed control.

## 3. Runtime Layers
Layer 0: Hardware Substrate
- CPU, memory, storage, NIC, timers, interrupts, optional GPU/accelerators.

Layer 0.5: Boot Framework
- Reset-vector entry, CPU bring-up, memory map setup, device discovery, secure runtime loading.
- Architecture-specific entry points for x86_64, ARM64, and RISC-V.

Layer 1: Hardware Abstraction
- W-HAL, driver boundary, safe resource handles, and board support packages.

Layer 1.5: Hardware Discovery and Driver Plane
- Device discovery, capability registry, and driver component framework.
- Device tree, ACPI, PCI, and embedded board manifests.

Layer 2: Core Runtime
- Bootstrap, memory manager, scheduler, event loop, resource manager.

Layer 3: WASM + Component Engine
- Validation, instantiation, execution contexts, component linker.

Layer 4: Actor Execution Model
- Actor lifecycle, mailboxing, supervision, migration primitives.

Layer 5: State and Messaging Fabric
- Append-only log, snapshotting, binary protocol, routing, backpressure.

Layer 6: Tooling and SDK
- CLI, package/build/deploy flows, WIT-driven SDK generation.

## 4. Core Subsystems
- RuntimeContext: root composition object for all runtime services.
- MemoryManager: arena/region allocators, quotas, snapshots.
- Scheduler: cooperative and priority/deadline aware actor scheduling.
- WasmEngine: pluggable backend interface (interpreter, JIT, AOT).
- ComponentRegistry: tracks component metadata and instance handles.
- CapabilityManager: token issuance, verification, revocation.
- HardwareRegistry: device discovery, capability exposure, and driver ownership.
- HardwareRuntime: CPU, memory, interrupt, timer, DMA, and peripheral abstraction.
- ResourceManager: lifecycle and quotas for hardware/logical resources.
- EventDispatcher: low-latency event transport between runtime subsystems.
- StateEngine: per-actor state, snapshot/replay and log compaction strategy.

## 5. Security Model
- Isolation unit: WASM component instance.
- Permission unit: capability token carrying least-privilege rights.
- Resource access: only through capability-guarded handles.
- Auditability: append-only security events and capability usage logs.
- Trust boundary: host runtime and component boundary only.

## 6. Reliability and Fault Tolerance
- Supervision trees for actor failure handling.
- Crash containment at component-instance granularity.
- Persistent replay from append-only logs and snapshots.
- Resource pressure controls: quotas, backpressure, admission control.

## 7. Performance Targets (Initial)
- Runtime image target: below 100 MB.
- Cold component startup target: microsecond-to-low-millisecond class.
- Messaging: millions of in-memory messages per second per node.
- Scheduling: multi-million lightweight actors per node (incremental milestone).

## 8. Architecture Decisions (Initial ADR Set)
- ADR-001: Zig-only core runtime for deterministic low-level control.
- ADR-002: Component Model as primary execution contract.
- ADR-003: Capability tokens over OS permissions.
- ADR-004: Binary protocol over text payloads.
- ADR-005: Cooperative actor runtime before preemptive complexity.

## 9. Non-goals (v0-v1)
- Native ABI process hosting.
- General-purpose POSIX compatibility layer.
- Full Kubernetes parity.
- Arbitrary host syscall passthrough.

## 10. Milestone Success Criteria
- M1: Runtime bootstrap + allocator + minimal event loop + static component load.
- M2: Actor mailbox + scheduler + capability checks in execution path.
- M3: WIT-driven component linking + state snapshots.
- M4: CLI packaging and benchmark suite with comparative baselines.
