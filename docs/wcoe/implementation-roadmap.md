# Wavium Initial Implementation Roadmap

## Objective
Convert architecture intent into verifiable runtime increments while preserving strict WASM-native boundaries.

## Planning Principles

- plan around contracts before code
- keep each phase testable on its own
- prefer small vertical slices over broad partial implementations
- keep docs, tests, and code in sync

## Phase A: Contract Lock (Week 1)
- Produce WAS v0.1 in specs/was/v0.1/.
- Define API contracts and module ownership matrix.
- Freeze invariants for security, memory, and scheduler semantics.

Exit criteria:
- All core contracts ratified.
- No module code merged without contract references.

Key deliverables:
- WAS v0.1 layer and interface docs
- architecture blueprint stabilization
- repo structure agreement

## Phase B: Foundation Runtime (Weeks 2-4)
- Implement wavium-core RuntimeContext and lifecycle skeleton.
- Implement wavium-memory arena and region allocator MVP.
- Implement wavium-scheduler cooperative queue and task progression.
- Implement wavium-security capability token verification path.

Exit criteria:
- Runtime boots and shuts down deterministically.
- Basic task execution loop with deterministic allocation behavior.

Key deliverables:
- runtime context
- allocator primitives
- scheduler smoke tests
- capability authorization path

## Phase C: WASM and Component Path (Weeks 5-7)
- Implement wavium-wasm interpreter-first execution pipeline.
- Implement wavium-wit parser MVP and canonical ABI subset.
- Implement wavium-component loader, link flow, lifecycle baseline.

Exit criteria:
- Minimal component can be loaded, linked, instantiated, executed.
- ABI conformance tests pass for initial type subset.

Key deliverables:
- component loader
- WIT parser subset
- canonical ABI codec coverage
- initial SDK generation path

## Phase D: Actor and State Runtime (Weeks 8-10)
- Implement wavium-actor mailbox, supervision, lifecycle transitions.
- Implement wavium-fabric binary messaging and backpressure controls.
- Implement wavium-state append-only log + snapshot MVP.

Exit criteria:
- Actor messaging works with bounded latency under stress.
- Crash/restart replay of actor state validated.

Key deliverables:
- mailbox implementation
- supervision semantics
- append-only log
- snapshot replay tests

## Phase E: WASI Surface and Tooling (Weeks 11-12)
- Implement wavium-wasi clocks/random/environment/storage APIs.
- Implement wavium-cli core commands (create/build/run/inspect).
- Implement wavium-sdk initial Zig/Rust/Go generation path.

Exit criteria:
- End-to-end dev loop from WIT to runnable component.

Key deliverables:
- CLI command surface
- packaging and trust flow
- developer documentation
- runtime simulation workflow

## Phase F: Scale and Federation (Weeks 13+)
- Add wavium-federation discovery and migration protocol baseline.
- Add backend extensions: JIT/AOT behind feature flags.
- Expand benchmarks to density and energy efficiency profiles.

Exit criteria:
- Multi-node actor migration demonstration.
- Reproducible benchmark harness and baseline reports.

Key deliverables:
- federation protocol baseline
- benchmark harness
- deployment orchestration
- cross-target capability planning

## Governance Rules
- Architecture first: all non-trivial modules require contract references.
- Test-first for API boundaries and ABI mappings.
- Performance regressions block merges at defined thresholds.
- Capability checks are mandatory in every resource access path.

## First Coding Slice
1. Create module skeletons for wavium-core, wavium-memory, wavium-scheduler, wavium-security.
2. Add a root build that compiles all four modules and test stubs.
3. Implement RuntimeContext with explicit allocator ownership.
4. Add deterministic allocator smoke tests.
5. Add cooperative scheduler smoke benchmark.
