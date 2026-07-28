# State Engine

The state engine stores durable state for components and actors.

It provides:
- append-only logs
- snapshots
- replay support
- deterministic recovery primitives

The state engine is intentionally simple so it can be validated under failure and replay scenarios.

## Related Documentation

- [Actor System](actor-system.md)
- [Memory Management](memory-management.md)
- [Wavium Runtime Spec](../specifications/wavium-runtime-spec.md)