# Wavium Toolchain Vision — Prompt Suite v1

> One executable (`wavium`) that provides everything a developer needs — from
> project creation to deployment on bare metal or cloud hardware.

This document is the toolchain counterpart to the 30-prompt Wavium
Engineering Prompt Suite (`docs/wcoe/prompts/milestones/`). It defines an
18-phase plan for a unified, batteries-included `wavium` CLI/toolchain,
comparable in ambition to `cargo`, `go`, and `zig`.

## Toolchain architecture overview

```text
                        Wavium CLI
                            │
 ┌──────────────────────────┼──────────────────────────┐
 │                          │                          │
Project                  Build                    Development
 │                          │                          │
new                    compile                  fmt
init                   package                  lint
add                    optimize                 doctor
remove                 sign                     benchmark
update                 bundle                   profile
 │                          │                          │
 ├──────────────────────────┼──────────────────────────┤
 │                          │                          │
Testing               Runtime                 Deployment
 │                          │                          │
test                  run                     deploy
coverage              debug                   flash
fuzz                  inspect                 image
stress                trace                   boot
 │                          │                          │
 ├──────────────────────────┼──────────────────────────┤
 │                          │                          │
SDK                   Components              Hardware
 │                          │                          │
wit                   component              board
bindgen               registry               probe
generate              publish                discover
```

Complete toolchain module map:

```
wavium/
cli/
sdk/
build/
compiler/
optimizer/
linker/
packager/
runtime/
toolchain/
board/
deploy/
component/
registry/
diagnostics/
profiler/
benchmarks/
documentation/
```

(Per this repo's established convention — see `/memories/repo/wavium-notes.md`
— these are NOT literal top-level directories; each phase below maps to a
`modules/wavium-<name>/` package instead, extending `modules/wavium-cli` and
`modules/wavium-build` where they already exist.)

---

## Phase 1 — Wavium CLI

Single executable, batteries included, extensible plugin system, beautiful
terminal output, cross-platform. Comparable in quality to cargo/go/zig/dotnet/
kubectl.

Commands: `new`, `init`, `build`, `run`, `package`, `test`, `benchmark`,
`profile`, `doctor`, `clean`, `update`, `deploy`, `flash`, `board`,
`component`, `registry`, `wit`, `fmt`, `lint`, `graph`, `inspect`, `debug`,
`shell`.

Implement: argument parser, colored output, progress bars, logging, help
system, auto-completion, plugin loading. Generate documentation and command
reference.

## Phase 2 — Project Generator

`wavium new hello-world|actor-service|component|library|driver|runtime-plugin|board`.

Generate: directory layout, build.zig, component manifest, WIT template,
README, GitHub workflow, tests, examples, documentation. Support template
customization.

## Phase 3 — Build System

Pipeline: Source → WIT Generation → Component Compilation → Optimization →
Package Generation → Signing → Deployment Image.

Implement: incremental builds, dependency graph, caching, parallel
compilation, cross-compilation, artifact management, build graph
visualization. Generate architecture diagrams.

## Phase 4 — WIT Toolchain

Commands: `wit init|validate|generate|format|inspect|graph|docs`.

Implement: parser, formatter, validator, AST, dependency graph, documentation
generator, binding generator. Support: Zig, Rust, Go, C, C++, Swift.

## Phase 5 — Component Toolchain

Commands: `component build|validate|sign|optimize|inspect|publish|graph`.

Implement: manifest, versioning, metadata, signing, dependency resolution,
validation, component registry integration.

## Phase 6 — Package Manager

Commands: `add|remove|search|install|update|publish`. Repository: `registry/`.

Features: semantic versioning, offline cache, dependency solver, integrity
verification, digital signatures, private registries, local registries, lock
files, workspace support.

## Phase 7 — Compiler Pipeline

Architecture: Language → Frontend → WIT → WebAssembly Component →
Optimization → Backend → Target Image.

Implement backend abstraction supporting: interpreter, Cranelift, future
Wavium backend, future LLVM backend. Design extensible interfaces without
hard-coding a specific backend.

## Phase 8 — Optimizer

Passes: dead code elimination, constant folding, component inlining,
capability optimization, memory optimization, actor optimization, startup
optimization, binary size reduction, cross-component optimization. Generate
optimization reports.

## Phase 9 — Linker

Features: component composition, dependency resolution, capability wiring,
WIT validation, memory layout, symbol resolution, binary merging. Generate
visual dependency graphs.

## Phase 10 — Board Support

Commands: `board list|add|remove|inspect|flash`.

Support: x86, ARM64, RISC-V. Future: Raspberry Pi, Jetson, BeagleBone, QEMU.
Implement board manifests, validation and flashing.

## Phase 11 — Deployment

Commands: `deploy local|qemu|hardware|cluster`, `image build|sign|inspect`.

Support deployment images for bare-metal execution.

## Phase 12 — Diagnostics

Commands: `doctor|inspect|trace|debug|dump`.

Check: CPU, memory, components, capabilities, drivers, boot, runtime.
Generate detailed diagnostic reports.

## Phase 13 — Profiler

Measure: actor latency, scheduling, memory, capability lookups, component
startup, cache behavior, cross-core messaging. Generate flame graphs and
markdown reports.

## Phase 14 — Benchmark Suite

Commands: `benchmark`, `benchmark runtime|memory|scheduler|actor|network`.
Support regression tracking and report generation.

## Phase 15 — Documentation Generator

Commands: `docs`, `docs api|architecture|wit`.

Generate: Markdown, HTML, PDF, Mermaid diagrams, API reference, architecture
reference, developer guides. Automatically extract documentation from
source.

## Phase 16 — Developer Experience

Implement: Language Server Protocol (LSP), code completion, hover
documentation, diagnostics, formatting, semantic highlighting, refactoring,
workspace support. Generate plugins for: VS Code, Neovim, JetBrains, Zed.

## Phase 17 — Security & Signing

Features: component signing, image signing, certificate management,
signature verification, SBOM generation, reproducible builds, license
scanning, integrity verification.

Commands: `sign|verify|sbom|attest`.

## Phase 18 — Visualization & Architecture

Commands: `graph runtime|components|actors|memory|scheduler`.

Generate: Mermaid, Graphviz, SVG, interactive HTML. Visualize dependencies,
actor topology, capability graphs and build pipelines.

---

## Long-term goal

Aim for the same developer experience that made `cargo`, `go`, and `zig`
successful: one cohesive tool instead of a collection of loosely connected
utilities. The Wavium CLI should orchestrate project creation, WIT
generation, component packaging, signing, deployment, diagnostics, and
benchmarking through a consistent interface.
