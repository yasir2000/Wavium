# wavium-smp

Status: implemented

Native Symmetric Multi-Processing (SMP) framework: boots all CPU cores with
no operating system, no kernel-owned scheduler, and no POSIX threads.
Cross-platform (x86_64 / ARM64 / RISC-V64) via decoupling seams - the module
never issues architecture-specific wake instructions itself.

- `src/core.zig` - `CoreRegistry`: runtime-owned core lifecycle state machine
  (`offline -> starting -> online -> halted -> offline`), the basis for CPU
  hotplug abstraction.
- `src/topology.zig` - deterministic processor topology detection (sockets,
  NUMA nodes, SMT siblings) given a core count and grouping parameters.
- `src/cpu.zig` - `CpuAffinity`: per-core affinity bitmask.
- `src/startup.zig` - `SecondaryLauncher`: brings a single Application
  Processor online via a bound `StartFn` seam (x86_64 INIT-SIPI-SIPI,
  ARM64 PSCI CPU_ON, RISC-V SBI HSM hart_start all live behind this).
- `src/boot.zig` - `initBootstrap`/`startAllSecondaries`: Bootstrap
  Processor initialization and orchestrated startup of every Application
  Processor.
- `src/ipi.zig` - minimal wake/halt inter-processor signal seam used to
  bring cores online/offline (full IPC/IPI messaging is a later milestone).

See [docs/images/smp-architecture-prompt16.mmd](../../docs/images/smp-architecture-prompt16.mmd)
for the boot/startup architecture diagram.
