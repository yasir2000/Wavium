# wavium-cache

Cache-aware runtime utilities for Wavium (Prompt 25 of the Wavium
Engineering Prompt Suite).

## API

```zig
cache_aligned(T)   // == alignment.CacheAligned(T)
padding(T)         // -> usize, padding bytes needed for a full cache line
prefetch(ptr, access, locality, target)
```

plus `hotcold.HotColdArray` for hot/cold data separation and
`packing.PackedFlags` for bit-packed structure packing.

## Files

- **`hierarchy.zig`** - `CacheHierarchy` models the L1/L2/L3 support
  requirement: per-level `size_bytes`/`line_bytes`, `default()` (a
  conservative 32 KiB/256 KiB/8 MiB hierarchy), `init()` for
  platform-probed sizes, and `tileCount(level, element_size,
  headroom_percent)` for sizing blocked/tiled algorithms so a working
  set fits within a given cache level (data locality).
- **`alignment.zig`** - `CacheAligned(T)` (aliased as `cache_aligned`
  in `lib.zig`): wraps `T` with `align(cache_line_bytes)` so every
  instance starts on its own cache line, preventing false sharing with
  neighboring data.
- **`padding.zig`** - `paddingBytes(T)`/`paddingFor(size)` (aliased as
  `padding` in `lib.zig`) compute the bytes needed to round a type up
  to a whole cache line; `Padded(T)` applies that padding so
  back-to-back array elements never share a line - the sibling half of
  false-sharing prevention (alignment controls the start, padding
  controls the extent).
- **`prefetch.zig`** - `prefetch(ptr, access, locality, target)`, a
  thin wrapper around `@prefetch` (comptime-parameterized, since the
  builtin requires comptime-known options), plus `prefetchRead`/
  `prefetchWrite` convenience wrappers.
- **`hotcold.zig`** - `HotColdArray(Hot, Cold, capacity)`: a
  fixed-capacity structure-of-arrays store keeping small, frequently
  accessed "hot" records separate from large, rarely accessed "cold"
  records, so hot loops touch far fewer cache lines than an
  array-of-structs layout would.
- **`packing.zig`** - `fieldSizeSum`/`paddingWaste` diagnose
  compiler-inserted layout padding; `PackedFlags(n)` bit-packs `n`
  booleans into the smallest unsigned integer that holds them, the
  structure-packing requirement.
- **`benchmark.zig`** - compares naive array-of-structs, cache-padded,
  and hot/cold-split summation over the same data, asserting all three
  produce identical results across a matrix of element counts (see
  the "no wall-clock timer" note below).
- **`lib.zig`** - aggregates all six + `moduleName()` + an end-to-end
  integration test exercising every requirement together.

## A note on benchmarking without a wall clock

This toolchain snapshot's `std.time` exposes only unit constants (no
`Timer`/timestamp API - real time sources now live behind an `Io`
provider this freestanding target doesn't have), so `benchmark.zig`
cannot report wall-clock timings. Per this repository's established
convention, benchmarks never assert on timing anyway (to avoid flaky
CI failures); this benchmark instead validates that all three cache
layouts (naive, padded, hot/cold-split) agree on the same computed
result across a matrix of element counts, exercising the exact same
code paths a timed run would.

## Requirements coverage

| Requirement | Implementation |
|---|---|
| L1/L2/L3 support | `hierarchy.CacheHierarchy` |
| Cache-line alignment | `alignment.CacheAligned` |
| False-sharing prevention | `alignment.CacheAligned` (start) + `padding.Padded` (extent) |
| Data locality | `hierarchy.tileCount` |
| Structure packing | `packing.PackedFlags`, `packing.paddingWaste` |
| `cache_aligned(T)` | `lib.cache_aligned` (= `alignment.CacheAligned`) |
| `prefetch()` | `prefetch.prefetch` / `lib.prefetch` |
| `padding()` | `lib.padding_fn` (= `padding.paddingBytes`) |
| Hot/cold data separation | `hotcold.HotColdArray` |
| Benchmark cache efficiency | `benchmark.runSuite` |
