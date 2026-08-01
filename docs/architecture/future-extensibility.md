# Future extensibility

> Part of the Prompt 30 deliverable ("Future many-core heterogeneous
> architecture"). Implementation: [`modules/wavium-heterogeneous`](../../modules/wavium-heterogeneous).

## Goal

The prompt lists eight future hardware classes (Big.LITTLE CPUs,
GPUs, NPUs, DPUs, SmartNICs, FPGAs, AI accelerators, TPUs) but is
explicit that Wavium should not implement any of them yet - only
"design extensible interfaces and abstractions". This document
describes how `wavium-heterogeneous` accommodates hardware,
capabilities, and policies that don't exist yet.

## Adding a new target kind

`ExecutionTargetKind` is a closed enum today (9 variants, one
`unknown_future`-style class is *not* pre-reserved - see below), but
adding a new kind is a single-file, additive change:

1. Add a variant to `target_kind.zig`'s `ExecutionTargetKind` and
   `execution_target_kinds` array, and a case to `kindName()`.
2. No other module needs to change - `target.zig`,
   `capability_mapping.zig`, `compute.zig`, and `migration.zig` all
   operate on `ExecutionTargetKind` generically and never switch on
   specific kinds.

This is deliberately different from, e.g., a `switch` over every
device type scattered through the scheduler - the only place that
enumerates kinds is `target_kind.zig` itself.

## Adding a new capability

Same pattern: add a variant to `ComputeCapability` in
`capability.zig`. Because `CapabilitySet` is a `std.EnumSet`, no
manual bitmask management is needed, and every existing
`ComputeRequest`/`scoreTarget`/`selectTarget` call site continues to
work unchanged - a request simply won't match targets that don't yet
advertise the new capability.

## Adding a new hardware backend

None of `DiscoverFn`, `ExecuteFn`, or `MigrateFn` are implemented
today - they are pure function-pointer contracts. Introducing support
for, say, a real NPU means:

1. Implement a `DiscoverFn` that probes the NPU vendor's enumeration
   API and returns `AcceleratorDescriptor{.kind = .npu, .capabilities = ...}`.
2. Implement an `ExecuteFn` that dispatches the opaque payload to the
   NPU's runtime.
3. Optionally implement a `MigrateFn` for that target class.
4. Wire the three function pointers into the relevant `Compute`,
   discovery, and migration call sites at startup.

No changes to `wavium-heterogeneous`'s own source are required - this
is the same "bring your own backend" pattern used by `wavium-hal`'s
`DriverLifecycle` and `wavium-topology`'s `ArchProbe`.

## Composability with the rest of the runtime

- **Actors and components** (`wavium-actor`, `wavium-component`)
  remain the unit of application logic; `wavium-heterogeneous` is an
  execution *substrate* they can optionally target for
  capability-heavy work (e.g. an actor requesting `tensor_ops` for an
  inference step), without giving up the actor/capability/component
  model described in the prompt's closing line.
- **Capability security** (`wavium-security`, ADR
  [003](../adr/003-capability-security.md)) already governs *what* an
  actor is permitted to do; `ComputeCapability` in this module is
  deliberately a distinct, narrower vocabulary (compute *capacity*
  requests, not security capabilities) to avoid overloading the term -
  a future integration could require a security capability grant
  before a `ComputeRequest` naming a sensitive target class (e.g. an
  FPGA that can reprogram itself) is honored.
- **Distributed services** (`wavium-dist-services`, Prompt 28) place
  services across *nodes*; `wavium-heterogeneous` places work across
  *target classes within a node*. A future combination could route a
  `ComputeRequest` to the nearest node that has a matching target
  registered, composing both layers.

## Scaling from embedded to cloud

The fixed-capacity `TargetRegistry` (`max_targets = 64`) intentionally
mirrors the fixed-size, allocation-free style used throughout Wavium
(`InstanceTable`, `TargetRegistry`, flamegraph frame tables, etc.) so
the same abstraction works unchanged on a small embedded board with a
single CPU cluster and a multi-socket cloud server node with several
accelerator classes attached - only the number of `register()` calls
made at startup differs.
