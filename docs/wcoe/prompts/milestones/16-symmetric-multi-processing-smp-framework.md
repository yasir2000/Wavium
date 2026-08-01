# Prompt 16 - Symmetric Multi-Processing (SMP) Framework


```text
You are designing the multi-core execution architecture for Wavium.

Wavium is a Zig-based bare-metal WebAssembly Cloud Operating Environment.

Implement native Symmetric Multi-Processing (SMP) support.

Requirements:

- Boot all CPU cores
- Primary (Bootstrap Processor) initialization
- Secondary (Application Processor) startup
- Cross-platform support:
    - x86_64
    - ARM64
    - RISC-V64
- Runtime-managed cores
- No operating system
- No scheduler dependency on kernel
- No POSIX threads

Repository:

runtime/smp/

Create:

boot.zig
cpu.zig
startup.zig
topology.zig
ipi.zig
core.zig

Features:

- Detect processor topology
- Start secondary cores
- CPU affinity
- Core state tracking
- Core online/offline management
- CPU hotplug abstraction (future)

Generate Mermaid architecture diagrams.

Provide comprehensive tests.
```

