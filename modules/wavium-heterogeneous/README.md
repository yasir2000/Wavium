# wavium-heterogeneous

Generic execution-target abstraction for future heterogeneous
hardware. Applications request **capabilities**, never devices - the
runtime resolves the request to the most appropriate registered
`ExecutionTarget` and dispatches through a function-pointer seam. No
hardware-specific driver code is implemented in this module (by
design - see the "Do not implement hardware-specific code yet"
requirement below).

## Requirements coverage (Prompt 30)

| Requirement | Source |
|---|---|
| Future hardware: Big.LITTLE CPUs, GPUs, NPUs, DPUs, SmartNICs, FPGAs, AI accelerators, TPUs | [`src/target_kind.zig`](src/target_kind.zig) - `ExecutionTargetKind` (9 variants: `cpu_big`, `cpu_little`, `gpu`, `npu`, `dpu`, `smartnic`, `fpga`, `ai_accelerator`, `tpu`) |
| Generic execution target abstraction | [`src/target.zig`](src/target.zig) - `ExecutionTarget` + `TargetRegistry` (fixed-capacity, capability-advertising, hardware-agnostic) |
| Applications request capabilities, not devices | [`src/capability.zig`](src/capability.zig) - `ComputeCapability` (8 variants) + `CapabilitySet`; [`src/capability_mapping.zig`](src/capability_mapping.zig) - `ComputeRequest{required: CapabilitySet}` |
| Example: `compute.execute()` | [`src/compute.zig`](src/compute.zig) - `Compute.execute(request, payload)` |
| The runtime schedules execution on the most appropriate processing unit | [`src/capability_mapping.zig`](src/capability_mapping.zig) - `selectTarget()` (hard-requirement subset match, best score wins) |
| Architecture doc: heterogeneous scheduling | [`docs/architecture/heterogeneous-scheduling.md`](../../docs/architecture/heterogeneous-scheduling.md) |
| Architecture doc: accelerator discovery | [`docs/architecture/accelerator-discovery.md`](../../docs/architecture/accelerator-discovery.md) |
| Architecture doc: capability mapping | [`docs/architecture/capability-mapping.md`](../../docs/architecture/capability-mapping.md) |
| Architecture doc: execution migration | [`docs/architecture/execution-migration.md`](../../docs/architecture/execution-migration.md) |
| Architecture doc: future extensibility | [`docs/architecture/future-extensibility.md`](../../docs/architecture/future-extensibility.md) |
| Do not implement hardware-specific code yet | Every integration point is a function-pointer seam: `DiscoverFn` ([`src/discovery.zig`](src/discovery.zig)), `ExecuteFn` ([`src/compute.zig`](src/compute.zig)), `MigrateFn` ([`src/migration.zig`](src/migration.zig)) - no vendor/driver code exists |

## Modules

| File | Purpose | Tests |
|---|---|---|
| `src/target_kind.zig` | `ExecutionTargetKind` enum + name lookup | 2 |
| `src/capability.zig` | `ComputeCapability` enum + `CapabilitySet` (`std.EnumSet`) | 2 |
| `src/target.zig` | `ExecutionTarget`, `TargetRegistry` (register/find/setAvailable/slice) | 3 |
| `src/discovery.zig` | `DiscoverFn` seam + `discoverAndRegister()` | 2 |
| `src/capability_mapping.zig` | `ComputeRequest`, `selectTarget()` (hard-requirement scoring) | 3 |
| `src/compute.zig` | `Compute.execute()` - the application-facing API | 3 |
| `src/migration.zig` | `MigrationPlan`, `MigrateFn` seam, `planAndMigrate()` | 3 |
| `src/lib.zig` | Aggregates all of the above + end-to-end integration test | 2 |

**Total: 18 tests**, all passing standalone (`cd modules/wavium-heterogeneous && zig build test`) and as part of the root workspace build.

## Design notes

- **Capability-first, not device-first.** `ComputeRequest` only
  carries a `CapabilitySet` - it never names `gpu`, `npu`, etc.
  Target selection is entirely mediated by `capability_mapping.selectTarget()`.
- **Hard-requirement matching.** A target must be a superset of the
  requested capabilities to be eligible at all (`scoreTarget` returns
  0 otherwise); among eligible targets the one advertising the most
  capabilities (closest match) wins. This avoids silently degrading
  a request onto a target that can't actually satisfy it.
- **Seams, not drivers.** `DiscoverFn`, `ExecuteFn`, and `MigrateFn`
  are function-pointer extension points, matching this repo's
  established seam convention (`ExecutionBackend`, `DriverLifecycle`,
  `ArchProbe`/`ProbeFn` from `wavium-topology`, `SyncFn` from
  `wavium-dist-services`). Real GPU/NPU/DPU/SmartNIC/FPGA backends
  plug in later without touching this module's contracts.
- **Relationship to existing modules.** This module sits above
  per-core scheduling (`wavium-coresched`), work stealing
  (`wavium-work-steal`), and per-node service placement
  (`wavium-dist-services`, Prompt 28): those modules distribute work
  across *homogeneous* CPU cores/nodes, while `wavium-heterogeneous`
  extends that model to *heterogeneous* processing units.
