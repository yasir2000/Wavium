# Prompt 22 - Per-Core Memory Allocators


```text
Design ultra-low-latency memory allocation.

Every CPU owns independent allocators.

Architecture:

Core 0

Arena

Pool

Slab

Region

----------------

Core 1

Arena

Pool

Slab

Region

Requirements:

- No allocator lock contention
- Thread-safe ownership
- Remote free support
- Cache locality
- Memory recycling
- Huge page support (future)

Repository:

memory/per_core/

Benchmark:

1 core

2 cores

8 cores

32 cores

128 cores
```

