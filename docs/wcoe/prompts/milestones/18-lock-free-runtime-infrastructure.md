# Prompt 18 - Lock-Free Runtime Infrastructure


```text
Implement lock-free concurrent runtime primitives for Wavium.

Required structures:

- MPMC queue
- MPSC queue
- SPSC queue
- Lock-free stack
- Lock-free freelist
- Ring buffer
- Atomic bitmap
- Concurrent hash map
- Hazard pointers or epoch-based reclamation

Repository:

runtime/concurrent/

Use:

- Zig atomics
- Compare-and-swap
- Memory ordering
- Cache-aware layouts
- False-sharing prevention

Benchmark against mutex implementations.
```

