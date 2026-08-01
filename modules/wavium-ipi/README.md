# wavium-ipi

Status: implemented

Inter-processor communication (IPC/IPI): architecture-abstracted interrupt
dispatch plus the `send`/`broadcast`/`multicast`/`barrier` primitives every
cross-core notification in this runtime is built from.

- `src/arch.zig` - `IpiArch` (x86 APIC / ARM GIC / RISC-V CLINT+SBI) and
  `ArchBackend{arch, send_fn}`: the one low-level "trigger an interrupt on
  another core" seam, bound at construction time so this module never
  depends on a concrete interrupt controller.
- `src/vector.zig` - `IpiVector` (wake / reschedule / memory_sync /
  mailbox_notify / halt): the logical reasons an IPI is sent, covering
  remote actor wake-up, cross-core scheduling, cross-core memory
  synchronization, and remote mailbox notification.
- `src/transport.zig` - `Transport{backend, local_core}`: `send()` (one
  target), `broadcast()` (every other core), `multicast()` (bitmask of
  targets), all built on `ArchBackend.send`.
- `src/barrier.zig` - `Barrier`: an atomic arrival counter used as the
  cross-core synchronization primitive (`arrive()` returns true only for
  the participant that completes the barrier).
- `src/benchmark.zig` - `runSuite()`: times `send`/`broadcast`/`multicast`
  against a no-op backend to measure this module's own dispatch overhead.

Builds on `modules/wavium-smp`'s minimal `IpiSender` (Prompt 16) by
providing the richer message-passing layer that was explicitly deferred to
this prompt, while staying decoupled from it (no cross-import - the arch
seam here plays the same role `IpiSender.send_fn` does there).
