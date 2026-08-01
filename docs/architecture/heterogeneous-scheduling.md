# Heterogeneous scheduling

> Part of the Prompt 30 deliverable ("Future many-core heterogeneous
> architecture"). Implementation: [`modules/wavium-heterogeneous`](../../modules/wavium-heterogeneous).

## Problem

Wavium's existing scheduling stack (`wavium-scheduler`,
`wavium-coresched`, `wavium-work-steal`, `wavium-massive-parallel`)
assumes a pool of *homogeneous* CPU cores: any core can run any actor,
and load balancing is a matter of moving work between otherwise
interchangeable execution units. Future hardware breaks that
assumption - a system may simultaneously expose Big.LITTLE CPU
clusters, GPUs, NPUs, DPUs, SmartNICs, FPGAs, AI accelerators, and
TPUs, each with wildly different execution models and each suited to
different kinds of work.

Heterogeneous scheduling is the problem of deciding *which class of
processing unit* a unit of work should run on, before the
homogeneous-core schedulers decide *which specific core/queue* within
that class.

## Approach: capability-first target selection

Wavium does not schedule computations onto a `gpu` or an `npu`
directly. Instead:

1. An application (or an internal runtime service) expresses a
   `ComputeRequest{required: CapabilitySet}` - e.g. "I need
   `tensor_ops`", never "give me the NPU".
2. `capability_mapping.selectTarget()` scans the `TargetRegistry` for
   every currently-`available` `ExecutionTarget` whose advertised
   capabilities are a **superset** of the request, and picks the
   best-scoring match (most capabilities advertised, i.e. the closest
   fit rather than an overpowered fallback).
3. `compute.execute()` dispatches the request to the chosen target
   through the `ExecuteFn` seam.

This mirrors the layering already used for homogeneous scheduling:
`wavium-scheduler`/`wavium-coresched` pick a *core* for actor-style
work; `wavium-heterogeneous` picks a *target class* first, and (once a
concrete GPU/NPU/etc. backend exists) that backend is free to run its
own internal, hardware-specific scheduler on top.

## Why capability-first, not device-first

- **Portability.** Code written against `ComputeCapability.tensor_ops`
  keeps working whether the underlying accelerator is an NPU, a TPU,
  or (in the absence of either) a CPU advertising `tensor_ops` via a
  software fallback.
- **Extensibility.** Adding a new `ExecutionTargetKind` (see
  [future-extensibility.md](future-extensibility.md)) never requires
  changing application code, only registering new targets with the
  right capability sets.
- **Hard requirements over best-effort.** `scoreTarget()` scores a
  target `0` unless it is a strict superset of the request - a
  request for `tensor_ops` will never silently land on a target that
  cannot actually perform tensor ops.

## Relationship to homogeneous scheduling

| Layer | Scope | Module |
|---|---|---|
| Actor placement across nodes | which node in a cluster | `wavium-dist-services` (Prompt 28) |
| Core/queue selection | which CPU core within a node | `wavium-scheduler`, `wavium-coresched`, `wavium-work-steal` |
| **Target class selection** | **which processing-unit class (CPU/GPU/NPU/...) within a node** | **`wavium-heterogeneous` (this document)** |

Heterogeneous scheduling composes with, rather than replaces, the
existing layers: once a target class is chosen, that target's own
internal scheduler (today: none, since no hardware-specific code is
implemented yet - see the module README) takes over.

## Non-goals (this phase)

Per the prompt's explicit constraint, this phase does **not**
implement any hardware-specific scheduling policy (e.g. GPU
occupancy-aware batching, NPU tensor-core allocation). It defines only
the abstraction that a future concrete scheduler would sit behind.
