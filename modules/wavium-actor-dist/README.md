# wavium-actor-dist

Status: implemented

Distributed actor execution across cores: each actor is described by an
`ActorDescriptor{id, capabilities, pinned_core}`; the runtime tracks which
core owns each actor's mailbox, routes messages to local or remote
execution accordingly, and load-balances placement while honoring pins.

- `src/ownership.zig` - `OwnershipTable`: fixed-capacity actor_id -> owning
  core registry (`register`/`ownerOf`/`transfer`/`unregister`).
- `src/mailbox_router.zig` - `MailboxRouter`: looks up the owning core and
  dispatches to a `deliver_local` or `deliver_remote` function-pointer seam
  (the seam is where a real per-core mailbox store or the cross-core
  IPC/IPI transport from Prompt 20 would plug in).
- `src/distribution.zig` - `ActorDescriptor` (capability bitmask + optional
  pin) and `chooseCore()`: least-loaded-core placement that always defers
  to `pinned_core` when set.
- `src/migration.zig` - `migrateActor()`: transfers ownership, rejecting
  any target other than a pinned actor's own pinned core.

This module builds on `modules/wavium-smp` (core identity) and
`modules/wavium-coresched` (per-core scheduling/queues, including its own
`migrateActor`/`rebalance` at the task level) conceptually, but stays
decoupled from both via plain data types and function-pointer seams rather
than direct imports.

See `docs/images/actor-distribution-state-prompt19.mmd` (ownership
lifecycle) and `docs/images/actor-distribution-sequence-prompt19.mmd`
(routing + migration flow).
