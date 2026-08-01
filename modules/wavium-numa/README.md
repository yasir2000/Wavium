# wavium-numa

Status: implemented

NUMA-aware execution: node detection with a distance matrix, actor
placement, memory-region migration, remote-access statistics, and a
NUMA-aware allocation seam.

- `src/node.zig` - `NumaTopology`/`detect()`: deterministic node + core
  mask + node-to-node distance matrix (ACPI-SLIT-style: 10 = local, 20 =
  remote in this flat model).
- `src/placement.zig` - `chooseNode()`: honors an explicit
  `preferred_node` (local memory preference / scheduler hint) or falls
  back to the least-loaded node.
- `src/statistics.zig` - `AccessStatistics`: per-node local vs. remote
  access counters and `remoteRatio()`.
- `src/migration.zig` - `evaluateMigration()`: approves migrating a memory
  region once its remote-access ratio crosses `remote_ratio_threshold`.
- `src/allocator.zig` - `NodeAllocator`: allocates on the preferred node
  first, falling back to the nearest node (by topology distance) if the
  preferred node is exhausted; `AllocFn` is a decoupling seam onto the
  real memory manager (e.g. `modules/wavium-memory`).

Integrates with the scheduler (`placement.PlacementHint`/`NodeLoad`), the
memory manager (`allocator.AllocFn` seam), and the actor runtime
(`modules/wavium-actor-dist`'s `pinned_core`/`chooseCore` play the
equivalent role at the core level; this module operates one level up, at
the NUMA-node level) via plain data types and function pointers rather
than direct imports.
