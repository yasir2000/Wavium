# Actor System

The actor system models isolated units of execution with explicit messaging and supervision.

Actors help Wavium scale concurrency without sharing mutable state by default.

Key properties:
- mailbox-driven communication
- predictable lifecycle transitions
- supervision for fault containment
- compatibility with component and state systems

## Related Documentation

- [ADR 005: Actor Model Choice](../adr/005-actor-model-choice.md)
- [Scheduler](scheduler.md)
- [State Engine](state-engine.md)