# Prompt 03 - Architecture Abstraction Layer


```text
Create the Wavium architecture abstraction layer.

Purpose:

Provide a unified interface between Wavium Runtime and different CPU architectures.


Supported architectures:

- x86_64
- ARM64
- RISC-V64


Implement:

arch/

├── cpu/
├── interrupts/
├── timers/
├── mmu/
├── registers/
├── atomic/
└── context/


Requirements:

Provide abstractions for:

- CPU initialization
- interrupt handling
- context switching
- atomic operations
- timers
- memory protection


Architecture-specific code must never leak into runtime code.


Runtime should call:

arch.cpu.init()

arch.timer.sleep()

arch.memory.map()


not:

x86 instructions directly.


Use Zig compile-time abstraction patterns.
```

