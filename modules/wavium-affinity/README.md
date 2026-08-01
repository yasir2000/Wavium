# wavium-affinity

CPU affinity management for Wavium (Prompt 24 of the Wavium
Engineering Prompt Suite).

## API

```zig
pinActor(table, actor_id, cpu, kind)
pinComponent(table, component_id, cpu, kind)
pinRuntimeService(table, service_id, cpu, kind)
```

where `kind` is `.soft` or `.hard`.

## Files

- **`entity.zig`** - `EntityKind` (actor/component/runtime_service) +
  `EntityRef`, unifying all three pinnable entity kinds under one
  table key.
- **`pin.zig`** - `PinTable`: soft/hard affinity registry.
  `allows(entity, cpu)` always returns `true` for unpinned or
  soft-pinned entities (a preference, not a constraint) and rejects
  every core but the pinned one for hard-pinned entities.
- **`group.zig`** - `GroupTable`: affinity groups - entities that
  should be co-located share one `assigned_cpu`, resolved with the
  same preference strength as a soft pin.
- **`isolation.zig`** - `CoreIsolation`: a bitmask of cores reserved
  for explicitly-pinned work only, excluded from general (non-pinned)
  placement decisions.
- **`latency.zig`** - `chooseLatencyOptimalCore`: honors a preferred
  (soft-pinned or group-assigned) core when available and
  non-isolated, else picks the least-loaded non-isolated candidate.
- **`scheduler.zig`** - `resolveCore`: the single scheduler
  integration entry point combining all of the above into one
  placement decision (hard pin > soft pin/group preference > latency
  optimization).

## Requirements coverage

| Requirement | How it's met |
|---|---|
| `pin(actor, cpu)` | `pinActor` |
| `pin(component, cpu)` | `pinComponent` |
| `pin(runtime_service, cpu)` | `pinRuntimeService` |
| Soft affinity | `AffinityKind.soft` - preference only |
| Hard affinity | `AffinityKind.hard` - enforced by `PinTable.allows` and always honored first in `resolveCore` |
| Affinity groups | `group.GroupTable` |
| Isolation | `isolation.CoreIsolation` |
| Latency optimization | `latency.chooseLatencyOptimalCore` |
| Scheduler integration | `scheduler.resolveCore` |

## Design note: scheduler integration

`wavium-coresched`'s `migration.zig` (Prompt 17) already has an
`affinity.TaskAffinity.allows(core_id)` check gating actor migration.
`scheduler.resolveCore` here is deliberately shaped so a scheduler can
call it for the same purpose - it is not cross-imported (kept
decoupled per this repository's established one-module-per-prompt
convention), but a real integration would call `resolveCore` before
`migrateActor` to pick the destination core, and/or call
`PinTable.allows` as an extra migration-time guard.

See `docs/images/cpu-affinity-prompt24.mmd` for a diagram of the
resolution flow.
