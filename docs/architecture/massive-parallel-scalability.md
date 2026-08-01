# Massive Parallel Runtime: Scalability Strategy

This document explains how Wavium scales its actor/component runtime
from small (8 logical CPU) deployments up to massive (1024 logical
CPU) many-core hardware without introducing a single bottleneck,
per Prompt 27 of the Wavium Engineering Prompt Suite.

## Goals

Wavium must run unmodified across 8, 16, 32, 64, 128, 256, 512, and
1024 logical CPUs (`modules/wavium-massive-parallel/src/scaling.zig`'s
`supported_core_counts`). The design must have:

- No centralized scheduler.
- Distributed metadata, actor registry, allocator, timers, and queues.
- Minimal synchronization.

## Strategy 1 — No centralized scheduler

Every core (or hardware thread) runs its own scheduler instance
(`modules/wavium-coresched`, Prompt 17) and its own work-stealing
actor deque set (`modules/wavium-work-steal`, Prompt 23). There is no
"scheduler core 0" that every other core reports to or waits on.
Idle cores discover work by randomly sampling peers and stealing
(`wavium-work-steal`'s `victim.selectRandomVictim`), which is an
O(1) decision per steal attempt regardless of `core_count` - a system
with 1024 cores makes exactly as many decisions per steal as a system
with 8.

## Strategy 2 — Sharded, not singleton, shared state

Two structures are inherently "global" in nature but MUST NOT become
single points of contention: the actor registry (which core owns
actor X?) and cluster metadata (what is node Y's descriptor?). Both
are split into independent shards
(`modules/wavium-massive-parallel/src/registry.zig`,
`src/metadata.zig`), addressed by
`sharding.computeShard(key, shard_count)` - a pure, deterministic hash
computation every core can run locally. Looking up any key only ever
touches the ONE shard that owns it; two cores operating on different
keys that happen to land on different shards never contend at all.

## Strategy 3 — Per-core ownership by default

Timers (`src/timers.zig`), queues (`src/queues.zig`), and memory
allocation (`src/allocator.zig`) all default to strict per-core
ownership: a core arms its own timers, pushes/pops its own queue, and
allocates from its own arena/pool
(`modules/wavium-percore-alloc`, Prompt 22). None of these operations
require a lock, atomic CAS loop, or cross-core message for the common
case. Cross-core movement only happens through explicit, occasional
operations - `queues.DistributedQueues.steal`, or NUMA-aware
allocation fallback in `modules/wavium-numa`'s `allocator.zig`
(Prompt 21) - which are amortized over many local operations, not
paid on every single one.

## Strategy 4 — Hierarchical fan-out for whole-system operations

Some operations are unavoidably "whole system" in nature - e.g.
reporting aggregate load for rebalancing decisions. A naive
implementation either uses one central collector (recreating the
centralized-scheduler problem) or has every core talk to every other
core (O(core_count²) messages). Instead,
`scaling.groupCountFor(core_count)` splits cores into
~√(core_count) groups of ~√(core_count) cores each (a balanced
two-level tree): a 1024-core system uses 32 groups of 32 cores, so
any aggregation is at most 32 local participants plus 32 group
representatives - never 1024.

## Strategy 5 — Cache and NUMA locality inform placement, not synchronization

`modules/wavium-topology` (Prompt 26) and `modules/wavium-numa`
(Prompt 21) expose which logical CPUs share an L3 cache domain or a
NUMA node. `modules/wavium-affinity` (Prompt 24) and
`wavium-work-steal`'s victim selection use this information to prefer
placing related actors near each other and to prefer stealing from a
cache/NUMA-local peer over a distant one - reducing the COST of any
synchronization that does happen, on top of minimizing how much of it
is needed in the first place.

## Summary table

| Concern | Centralized approach (avoided) | Wavium's distributed approach |
|---|---|---|
| Scheduling | One global run queue | Per-core scheduler + work stealing |
| Actor lookup | One global registry + lock | Sharded registry, hash-routed |
| Cluster metadata | One config service | Sharded metadata store |
| Timers | One global timer wheel/thread | Per-core timer wheels |
| Task queues | One global queue | Per-core queues + occasional steal |
| Memory allocation | One global heap/lock | Per-core allocator + NUMA fallback |
| Load reporting at scale | All-to-all or single collector | Hierarchical ~√N group fan-out |

## Implementation

See [`modules/wavium-massive-parallel/`](../../modules/wavium-massive-parallel/)
for the concrete `scaling`/`sharding`/`registry`/`metadata`/`timers`/
`queues`/`allocator` types implementing the strategies above, and
[`docs/images/massive-parallel-runtime-prompt27.mmd`](../images/massive-parallel-runtime-prompt27.mmd)
for an architecture diagram.
