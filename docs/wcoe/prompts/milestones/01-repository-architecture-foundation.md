# Prompt 01 - Repository Architecture Foundation


```text
You are the principal systems architect for the Wavium project.

Wavium is a Zig-based bare-metal WebAssembly Cloud Operating Environment.

Design and scaffold the complete repository architecture.

Architectural principles:

- No operating system dependency
- No libc
- No POSIX
- No syscalls
- No ELF execution model
- No kernel dependency
- No containers
- No traditional runtime layers

Wavium provides:

- WebAssembly Component Model execution
- WIT interface system
- Capability-based security
- Actor-based execution model
- Deterministic memory management
- Hardware abstraction layer
- Bare-metal execution


Create this repository:

wavium/

├── boot/
├── arch/
├── runtime/
├── wasm/
├── wit/
├── component/
├── actor/
├── scheduler/
├── memory/
├── security/
├── capability/
├── hal/
├── drivers/
├── devices/
├── filesystem/
├── network/
├── storage/
├── sdk/
├── cli/
├── build/
├── packages/
├── tests/
├── benchmarks/
└── docs/


Use Zig as the primary implementation language.

Create:

- build.zig
- build configuration
- module structure
- testing framework
- documentation structure

Do not implement functionality yet.

Create only architecture scaffolding with TODO markers.
```

