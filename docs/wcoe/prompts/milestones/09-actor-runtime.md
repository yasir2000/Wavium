# Prompt 09 - Actor Runtime


```text
Implement the Wavium Actor Runtime.


Model:

Actor:

- owns state
- owns mailbox
- has capabilities
- executes WebAssembly component logic


Create:


actor/

├── actor.zig
├── mailbox.zig
├── message.zig
├── lifecycle.zig
└── supervision.zig


Features:

- actor creation
- messaging
- isolation
- supervision
- failure recovery


Optimize for:

millions of lightweight actors.
```

