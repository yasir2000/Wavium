# wavium-coresched

Status: implemented

Per-core scheduler architecture for many-core systems: every CPU owns an
independent scheduler instance (ready queue / actor queue / timer queue),
each driven by its own `Worker`. Cross-core work stealing, actor migration,
CPU affinity, and a NUMA-aware greedy load balancer let work move between
cores without any global lock.

- `src/core_scheduler.zig` - `CoreScheduler` (ready/actor/timer queues,
  bounded array-backed, no allocator). The ready queue's length is an
  atomic counter so other cores can read its depth without a lock.
- `src/worker.zig` - `Worker`: pops and executes tasks from its own core's
  ready queue via a bound `TaskFn` seam.
- `src/steal.zig` - `stealHalf`: moves half of a victim core's ready queue
  into a thief core's.
- `src/affinity.zig` - `TaskAffinity`: per-core allow-mask used to pin
  actors/tasks and to gate migration.
- `src/migration.zig` - `migrateActor`: moves an actor between cores'
  actor queues, honoring affinity and restoring on failure.
- `src/balancer.zig` - `rebalance`: finds the busiest/idlest core (same
  NUMA node preferred, cross-node fallback) and triggers a steal when the
  ready-queue depth difference exceeds a threshold.

Note: this module is distinct from `modules/wavium-scheduler` (the
single global priority scheduler from an earlier milestone) - that module
still exists unchanged; this one models the per-CPU architecture described
by the per-core-scheduler prompt.

See [docs/images/per-core-scheduler-prompt17.mmd](../../docs/images/per-core-scheduler-prompt17.mmd).
