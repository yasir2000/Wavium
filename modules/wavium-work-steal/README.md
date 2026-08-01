# wavium-work-steal

Work-stealing actor scheduler for Wavium (Prompt 23 of the Wavium
Engineering Prompt Suite).

Every worker owns an independent ready queue. Idle workers steal
actors from busy workers rather than blocking.

## Files

- **`deque.zig`** - `ChaseLevDeque(T, capacity)`: fixed-capacity
  Chase-Lev/Arora work-stealing deque. Owner uses `pushBottom`/
  `popBottom` (LIFO); any other worker uses `steal` (FIFO, top of the
  deque, oldest work first).
- **`victim.zig`** - `Rng` (dependency-free xorshift32 PRNG, since this
  freestanding runtime has no OS entropy source) + `selectRandomVictim`
  (randomized stealing) + `selectBusiestVictim` (load-biased
  alternative).
- **`priority.zig`** - `Priority` (`low`/`normal`/`high`) +
  `PriorityQueues`: one `ChaseLevDeque` per priority class per worker;
  both local pop and steal always try `high` before `normal` before
  `low` (priority stealing).
- **`fairness.zig`** - `tick`/`AgingEntry`: promotes an actor that has
  waited `promotion_threshold` ticks in a lower class to the next
  class up, bounding worst-case wait time (starvation prevention).
  `RoundRobin` rotates a starting index for unbiased scheduling-round
  iteration (fairness).
- **`worker.zig`** - `Worker(capacity)`: ties the above together -
  `submit`/`popOwn` for the owning core, `stealFrom(workers[])` for the
  idle-worker steal path (randomized victim selection + priority
  stealing in one call).
- **`benchmark.zig`** - `runSuite(worker_count, actors_per_worker)`:
  seeds all work onto worker 0 (the worst case for imbalance) and
  measures how long every other worker takes to drain it via stealing.

## Requirements coverage

| Requirement | How it's met |
|---|---|
| Chase-Lev deque or equivalent | `deque.ChaseLevDeque` |
| Victim selection | `victim.selectRandomVictim` / `selectBusiestVictim` |
| Randomized stealing | `victim.Rng` (xorshift32) feeds `selectRandomVictim` |
| Priority stealing | `priority.PriorityQueues` (per-class deques, high-first) |
| Fairness | `fairness.RoundRobin` + randomized victim selection |
| Starvation prevention | `fairness.tick`/`AgingEntry` (priority promotion by wait time) |
| Performance benchmarks | `benchmark.runSuite` |

## Design note: decoupling from `wavium-coresched`

`wavium-coresched`'s `steal.zig` (Prompt 17) already has a simple
`stealHalf(victim, thief)` that moves half of a plain ready queue's
tasks. This module is deliberately independent: it operates at
**actor** granularity with a real Chase-Lev deque (rather than a plain
array `stealHalf`), adds priority classes and starvation prevention
that `wavium-coresched` does not have, and is not cross-imported, per
this repository's established one-module-per-prompt convention.

See `docs/images/work-stealing-prompt23.mmd` for a diagram of the
push/pop/steal paths and the priority/aging relationship.
