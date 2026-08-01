# Prompt 19 - Actor Distribution Across Cores


```text
Implement distributed actor execution.

Each actor owns:

- mailbox
- state
- capability set

Scheduler distributes actors across cores.

Support:

- actor migration
- mailbox ownership
- local execution
- remote message delivery
- actor pinning
- load balancing

Repository:

actor/distributed/

Create:

migration.zig
mailbox_router.zig
ownership.zig
distribution.zig

Generate state diagrams and sequence diagrams.
```

