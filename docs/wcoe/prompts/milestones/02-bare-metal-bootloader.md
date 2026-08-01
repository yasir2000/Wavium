# Prompt 02 - Bare Metal Bootloader


```text
Implement the Wavium bare-metal boot system.

Goal:

Boot directly from hardware into Wavium Runtime without Linux, libc, BIOS runtime services, or operating system support.


Architecture:

Hardware Reset

↓

Wavium Bootloader

↓

CPU Initialization

↓

Memory Initialization

↓

Hardware Discovery

↓

Runtime Loader

↓

Wavium Runtime


Support initially:

- x86_64
- ARM64
- RISC-V64


Implement:

boot/

├── reset/
├── startup/
├── cpu/
├── memory/
├── loader/
└── entry/


Requirements:

- Zig freestanding mode
- no_std equivalent
- no libc
- no OS calls
- custom entry point
- linker scripts
- memory layout definitions
- stack initialization


Generate:

- boot sequence documentation
- memory map documentation
- architecture diagrams using Mermaid
- test boot image
```

