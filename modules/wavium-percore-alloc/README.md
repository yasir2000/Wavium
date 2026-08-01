# wavium-percore-alloc

Ultra-low-latency, per-core memory allocation for Wavium (Prompt 22 of
the Wavium Engineering Prompt Suite).

Every CPU core owns an independent `CoreAllocator` built from four
layers, matching the prompt's architecture diagram:

```
Core 0                  Core 1
  Arena                   Arena
  Pool                    Pool
  Slab                    Slab
  Region                  Region
```

## Layers

- **`region.zig`** - `Region`: the coarse per-core backing memory
  carved out once at boot/init time via a watermark. Nothing a core
  allocates ever comes from another core's `Region`, which is what
  gives the hierarchy its cache locality.
- **`slab.zig`** - `Slab`: manages several `Pool`s of fixed block
  sizes (16/32/64/128/256 bytes). Requests are rounded up to the
  nearest size class.
- **`pool.zig`** - `Pool(block_size, block_count)`: a single size
  class's free-index stack. `acquire`/`release` are O(1), no locks.
- **`arena.zig`** - `Arena`: a bump/watermark allocator for
  phase-scoped allocations that are all released together via
  `reset()` rather than individually.
- **`remote_free.zig`** - `RemoteFreeQueue(T, capacity)`: a bounded,
  lock-free MPSC queue (Vyukov-style) used to let a *different* core
  return a block without ever touching the owner's `Slab` directly.
- **`core_allocator.zig`** - `CoreAllocator`: the per-core facade
  tying `Slab` + `RemoteFreeQueue` together with ownership-aware
  `free(block, size, calling_core)` dispatch and `reclaimRemote()`.
- **`benchmark.zig`** - `runSuite(core_count, ops_per_core)` simulates
  the prompt's exact benchmark matrix (1 / 2 / 8 / 32 / 128 cores).

## Requirements coverage

| Requirement | How it's met |
|---|---|
| No allocator lock contention | Owner's `alloc`/`freeLocal` path touches only its own `Slab`/`Pool`/`Arena`/`Region` - no lock, no atomic. |
| Thread-safe ownership | `CoreAllocator.core_id` + `free(block, size, calling_core)` dispatch. |
| Remote free support | `RemoteFreeQueue` (lock-free bounded MPSC) + `reclaimRemote()`. |
| Cache locality | Per-core `Region`/`Slab` storage, never interleaved across cores. |
| Memory recycling | `Pool` free-index stack + `Arena`/`Region` watermark reset. |
| Huge page support (future) | `huge_page_size_bytes` constant reserved in `lib.zig`; not yet wired to an MMU/page-table layer. |

## Design note: decoupling from `wavium-lockfree`

`remote_free.zig` reimplements the Vyukov MPSC pattern locally rather
than importing `wavium-lockfree`'s `MpscQueue`, keeping this module
self-contained per this repository's established one-module-per-prompt
convention (see `wavium-actor-dist`, `wavium-ipi`, `wavium-numa`).

## Integration points

- `wavium-numa`'s `allocator.NodeAllocator` (Prompt 21) operates at
  NUMA-node granularity and would bind its `AllocFn` seam to a
  `CoreAllocator` per core within that node.
- `wavium-coresched`'s per-core scheduler (Prompt 17) would call
  `reclaimRemote()` once per scheduling quantum to drain any
  cross-core frees without blocking the hot scheduling path.

See `docs/images/percore-allocator-prompt22.mmd` for a diagram of the
allocator hierarchy and the remote-free path.
