# Prompt 04 - Physical Memory Manager


```text
Implement the Wavium physical memory subsystem.

Wavium has no:

- malloc
- mmap
- OS allocator
- kernel allocator


Create:


memory/

├── physical/
├── allocator/
├── arena/
├── pool/
├── slab/
├── region/
└── protection/


Implement:

- physical memory discovery
- allocation
- freeing
- ownership tracking
- memory regions
- alignment handling


Design for:

- deterministic latency
- zero garbage collection
- low fragmentation
- embedded systems
- cloud workloads


Provide:

allocation benchmarks
memory diagrams
test suite
```

