# wavium-topology

Complete hardware topology discovery for the Wavium runtime (Prompt 26
of the Wavium Engineering Prompt Suite).

Discovers/models the full physical hierarchy of a machine - sockets,
NUMA nodes, packages, cores, logical CPUs, cache-sharing domains, and
memory controllers - as a single `TopologyGraph`, then exports that
graph into the plain shapes the scheduler and the rest of the runtime
need.

## Files

| File | Purpose |
|---|---|
| `src/ids.zig` | ID type aliases (`SocketId`, `PackageId`, `CoreId`, `LogicalCpuId`, `NumaNodeId`) and `LogicalCpuDescriptor`. |
| `src/arch_probe.zig` | `DiscoveryMethod` enum (`x86_cpuid`, `arm64_mpidr`, `riscv_hart_sbi`) and the `ArchProbe`/`ProbeFn` seam for pluggable per-architecture identity probing (x86 CPUID leaves, ARM64 `MPIDR_EL1`, RISC-V hart IDs via SBI HSM). |
| `src/cache_domains.zig` | `CacheDomainTable`: which logical CPUs share which L1/L2/L3 cache instance, modeled as a `u64` sharing bitmask per domain. |
| `src/memory_controller.zig` | `MemoryControllerTable`: memory controllers, their NUMA node, and capacity. |
| `src/graph.zig` | `TopologyGraph`: aggregates CPUs, cache domains, and memory controllers with lookup helpers. |
| `src/discovery.zig` | `discoverTopology(...)`: deterministically builds a full, internally-consistent `TopologyGraph` for a requested shape (sockets × packages × cores × SMT width, NUMA nodes/socket, memory controllers/socket). |
| `src/export.zig` | `exportForScheduler` / `exportForRuntime`: flattens a `TopologyGraph` into `SchedulerCoreHint` (per-CPU NUMA node + L3 domain) and `RuntimeTopologySummary` (whole-system counts). |
| `src/lib.zig` | Aggregates all of the above, `moduleName()`, end-to-end integration test. |

## Why discovery is deterministic here

Real discovery walks x86 CPUID leaves 0x0B/0x1F, reads ARM64
`MPIDR_EL1` affinity fields, or queries RISC-V hart IDs via SBI HSM
(the `arch_probe.ArchProbe`/`ProbeFn` seam exists for exactly this,
mirroring the `ExecutionBackend`/`DriverLifecycle` function-pointer
decoupling pattern used elsewhere in this repo). Without real hardware
to probe in this environment, `discoverTopology` builds the same
`TopologyGraph` shape deterministically from a requested socket/
package/core/SMT layout - the same approach `wavium-smp`'s
`topology.zig` (Prompt 16) and `wavium-numa`'s `node.zig` (Prompt 21)
already use - so downstream consumers (scheduler, NUMA-aware
allocators, cache-aware runtime) have a concrete, testable graph to
build against.

## Cache hierarchy sharing model

`cache_domains.zig`'s `CacheDomainTable` is deliberately distinct from
`wavium-cache`'s (Prompt 25) size-based `CacheHierarchy` model: this
module answers "which logical CPUs share this cache instance"
(topology), while `wavium-cache` answers "how big is this cache level
and how should data be tiled/aligned for it" (data layout). The two
modules do not cross-import, per this repo's established
decoupling convention.

## Requirements coverage

| Prompt requirement | Implementation |
|---|---|
| Sockets | `ids.SocketId`, `TopologyGraph.socket_count` |
| NUMA Nodes | `ids.NumaNodeId`, `TopologyGraph.numa_node_count`, `LogicalCpuDescriptor.numa_node` |
| Packages | `ids.PackageId`, `TopologyGraph.package_count` |
| Cores | `ids.CoreId`, `TopologyGraph.core_count` |
| Logical CPUs | `ids.LogicalCpuId`, `LogicalCpuDescriptor`, `TopologyGraph.cpuSlice()` |
| Cache hierarchy | `cache_domains.CacheDomainTable` (L1/L2/L3 sharing masks) |
| Memory controllers | `memory_controller.MemoryControllerTable` |
| Topology graph | `graph.TopologyGraph` |
| x86 CPUID / ARM64 / RISC-V | `arch_probe.DiscoveryMethod` + `ArchProbe`/`ProbeFn` seam |
| Export to scheduler and runtime | `export.exportForScheduler`, `export.exportForRuntime` |

## Testing

```
zig build --build-file modules/wavium-topology/build.zig test
```

17 tests covering ID/descriptor construction, arch probing (via a test
double), cache domain sharing, memory controller lookup, graph
assembly, deterministic discovery across single- and multi-socket
NUMA shapes, cache-mask overflow rejection (>64 logical CPUs), and
scheduler/runtime export.
