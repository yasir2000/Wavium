# wavium-massive-parallel

Scalable runtime infrastructure for 8 up to 1024 logical CPUs (Prompt
27 of the Wavium Engineering Prompt Suite).

## Files

| File | Purpose |
|---|---|
| `src/scaling.zig` | `supported_core_counts` (8/16/32/64/128/256/512/1024), `isSupportedScale`, and `groupCountFor`/`groupOf` hierarchical fan-out grouping (~sqrt(core_count) groups) so higher-level aggregation never needs O(core_count) or O(core_count²) participants. |
| `src/sharding.zig` | `computeShard(key, shard_count)`: deterministic, allocator-free hashing (Wyhash) so any core can independently compute which shard owns a key - no lookup table, no coordination. |
| `src/registry.zig` | `DistributedActorRegistry`: actor ownership sharded across independent tables; register/lookup/unregister only ever touch the one shard owning a given actor id. |
| `src/metadata.zig` | `DistributedMetadataStore`: generic sharded cluster metadata/config key-value store, same sharding strategy as the registry. |
| `src/timers.zig` | `DistributedTimers`: one independent timer wheel per core - arming/expiring timers never crosses cores. |
| `src/queues.zig` | `DistributedQueues`: one bounded FIFO queue per core, with an explicit, occasional `steal` for cross-core rebalancing (not a per-operation synchronization cost). |
| `src/allocator.zig` | `DistributedAllocatorRouter`: routes allocation requests to a per-core `AllocFn`/`FreeFn` seam (bindable to `wavium-percore-alloc`'s `CoreAllocator` or any other per-core allocator, without a cross-import). |
| `src/lib.zig` | Aggregates all of the above, `moduleName()`, end-to-end 64-core integration test. |

## Why this module contains no scheduler

"No centralized scheduler" is satisfied by what this module
deliberately does **not** contain: there is no global scheduler type
here at all. Per-core scheduling already exists in `wavium-coresched`
(Prompt 17, one `CoreScheduler` instance per core) and
`wavium-work-steal` (Prompt 23, Chase-Lev deques + randomized
stealing). This module instead supplies the sharded/distributed data
structures (registry, metadata, timers, queues, allocator routing)
those per-core schedulers need so that going from 8 to 1024 cores
doesn't introduce a new bottleneck anywhere in the stack.

## Minimal synchronization strategy

- **Registry / metadata**: sharded by `sharding.computeShard`. A core
  only ever contends with other cores that happen to hash to the
  *same* shard - not with the whole system.
- **Timers / queues / allocator**: strictly per-core. A core touches
  only its own timer wheel, own queue, own allocator seam by default;
  cross-core movement (`queues.steal`) is an explicit, infrequent
  operation, not baked into every push/pop.
- **Hierarchical fan-out** (`scaling.groupCountFor`/`groupOf`): when
  something DOES need whole-system visibility (e.g. load reporting),
  it's organized as a two-level tree with ~sqrt(core_count) groups
  instead of all-to-all communication, keeping the fan-out small even
  at the 1024-core tier.

See [`docs/architecture/massive-parallel-scalability.md`](../../docs/architecture/massive-parallel-scalability.md)
for the full scalability-strategy writeup this prompt also requires.

## Requirements coverage

| Prompt requirement | Implementation |
|---|---|
| Scalable runtime (8..1024 logical CPUs) | `scaling.supported_core_counts` / `isSupportedScale` |
| No centralized scheduler | No scheduler type in this module; builds on `wavium-coresched`/`wavium-work-steal`'s per-core schedulers |
| Distributed metadata | `metadata.DistributedMetadataStore` |
| Distributed actor registry | `registry.DistributedActorRegistry` |
| Distributed allocator | `allocator.DistributedAllocatorRouter` |
| Distributed timers | `timers.DistributedTimers` |
| Distributed queues | `queues.DistributedQueues` |
| Minimal synchronization | Sharding (`sharding.zig`) + per-core ownership + hierarchical fan-out (`scaling.groupCountFor`) |
| Architecture documentation | `docs/architecture/massive-parallel-scalability.md` |

## Testing

```
zig build --build-file modules/wavium-massive-parallel/build.zig test
```

20 tests covering scale-tier validation, hierarchical grouping,
sharding distribution, registry/metadata/timers/queues/allocator
correctness, and an end-to-end 64-core scenario exercising every
subsystem together.
