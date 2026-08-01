# wavium-lockfree

Status: implemented

Lock-free concurrent runtime primitives, built directly on Zig atomics/CAS
with no OS mutexes (there is no operating system underneath this runtime).
Everything is fixed-capacity and allocator-free, matching this codebase's
conventions.

- `src/ring_buffer.zig` - plain (non-atomic) circular buffer; the base
  storage shape the atomic queues build on.
- `src/spsc_queue.zig` - wait-free single-producer/single-consumer queue.
- `src/mpsc_queue.zig` - lock-free multi-producer/single-consumer queue
  (Vyukov-style per-cell sequence numbers on the push side only).
- `src/mpmc_queue.zig` - lock-free multi-producer/multi-consumer queue
  (full Vyukov bounded MPMC algorithm).
- `src/freelist.zig` - lock-free freelist over a fixed slot pool, using a
  generation-tagged head pointer to defeat ABA.
- `src/stack.zig` - lock-free LIFO stack (Treiber-style), built on top of
  `freelist` for slot allocation plus its own tagged LIFO chain.
- `src/bitmap.zig` - atomic bitmap (`fetchOr`/`fetchAnd`, no CAS loop
  needed) with `testAndSet`/`findFirstClear`/`popCount`.
- `src/hashmap.zig` - fixed-capacity concurrent hash map (open addressing,
  linear probing, per-slot atomic state machine: empty/reserved/occupied/
  tombstone).
- `src/reclamation.zig` - epoch-based reclamation (`enter`/`leave`/
  `retire`/`reclaim`), modeled around one participant per core.
- `src/benchmark.zig` - `SpinlockQueue` baseline + `compareQueues`,
  measuring lock-free vs. lock-guarded push/pop overhead.

All hot atomic fields (queue head/tail indices, freelist/stack tagged
heads, the epoch counter) are aligned to `cache_line_bytes` (64) to
prevent false sharing between cores.
