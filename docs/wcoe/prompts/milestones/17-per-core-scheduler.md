# Prompt 17 - Per-Core Scheduler


```text
Design Wavium's scheduler for many-core systems.

Each CPU owns an independent scheduler.

Architecture:

CPU0

Ready Queue

Actor Queue

Timer Queue

Worker

-------------------

CPU1

Ready Queue

Actor Queue

Timer Queue

Worker

-------------------

CPU2

...

Requirements:

- One scheduler per CPU
- Lock-free local queues
- Work stealing
- CPU affinity
- NUMA awareness
- Actor migration
- Load balancing

Implement:

scheduler/

core_scheduler.zig
worker.zig
steal.zig
affinity.zig
migration.zig
balancer.zig

Avoid global locks whenever possible.

Use Zig atomics.
```

