# Wavium

[![Version](https://img.shields.io/badge/version-0.1.0-0f766e?style=for-the-badge&logo=semantic-release&logoColor=white)](build.zig.zon)
[![License](https://img.shields.io/badge/license-Apache_2.0-2563eb?style=for-the-badge&logo=apache&logoColor=white)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-available-111827?style=for-the-badge&logo=readthedocs&logoColor=white)](docs/README.md)
[![CI](https://img.shields.io/badge/ci-passing-16a34a?style=for-the-badge&logo=githubactions&logoColor=white)](.github/workflows/ci.yml)

<img width="250" height="110" alt="Wavium logo" src="https://github.com/user-attachments/assets/cb1f62d9-a6e8-419f-aba5-62ab624dd094" />

Wavium is a Zig-based, bare-metal WebAssembly execution platform for running portable WebAssembly Components directly on hardware.

It is designed as infrastructure rather than an application framework. The stable boundary is the WebAssembly Component Model, the contract surface is WIT, and the execution substrate is a capability-secured runtime that can boot on bare metal, simulate in CI, and scale across hardware classes.

## System Model

```mermaid
flowchart TD
    App[Application] --> Comp[WASM Component]
    Comp --> Wit[WIT Interface Contract]
    Wit --> Run[Wavium Runtime]
    Run --> Hal[Hardware Capability Layer]
    Hal --> Hw[Physical Hardware]
```

Traditional systems usually follow the path:

Application -> Libraries -> Operating System -> Kernel -> Hardware

Wavium follows a component-native model:

Application -> WASM Component -> WIT Contract -> Wavium Runtime -> Hardware

This architecture is intended to improve:
- portability across languages and targets
- security through explicit capability boundaries
- scalability through portable component packaging
- performance through bare-metal execution and deterministic runtime control
- polyglot development through generated SDKs

## Documentation

Primary documentation lives under [docs](docs):
- [Vision](docs/vision/project-vision.md)
- [Architecture](docs/architecture/overview.md)
- [Runtime](docs/runtime/wavium-core.md)
- [Hardware](docs/hardware/bootloader.md)
- [Toolchain](docs/toolchain/cli.md)
- [Developers](docs/developers/getting-started.md)
- [Specifications](docs/specifications/wavium-runtime-spec.md)
- [Tutorials](docs/tutorials/hello-world.md)
- [Reference](docs/reference/command-reference.md)
- [ADRs](docs/adr/001-why-zig.md)
- [WCOE Index](docs/wcoe/README.md)

Supporting project docs:
- [docs/README.md](docs/README.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [ROADMAP.md](ROADMAP.md)
- [CHANGELOG.md](CHANGELOG.md)

## Release & Versioning

Wavium uses semantic versioning for the repository and published artifacts.

- Current root version: 0.1.0
- The root package version is defined in [build.zig.zon](build.zig.zon)
- SDK scaffolds track the same baseline version across language targets
- Release notes are recorded in [CHANGELOG.md](CHANGELOG.md)
- Release policy and channel definitions are tracked in [release-config.yml](release-config.yml)
- The release workflow scaffold lives in [`.github/workflows/release.yml`](.github/workflows/release.yml)

Release tracks:
- stable: tagged releases intended for general consumption
- nightly: pre-release or in-progress builds used for validation and internal testing

Versioning rules:
- patch releases fix bugs or documentation issues without contract changes
- minor releases add backward-compatible features
- major releases may change contracts, packaging, or runtime assumptions

## Repository Workflow

Scripts:
- [scripts/test.sh](scripts/test.sh) and [scripts/test.ps1](scripts/test.ps1)
- [scripts/build.sh](scripts/build.sh) and [scripts/build.ps1](scripts/build.ps1)
- [scripts/sdk-status.sh](scripts/sdk-status.sh) and [scripts/sdk-status.ps1](scripts/sdk-status.ps1)
- [scripts/ci.sh](scripts/ci.sh) and [scripts/ci.ps1](scripts/ci.ps1)

CI workflows:
- [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
- [`.github/workflows/build.yml`](.github/workflows/build.yml)
- [`.github/workflows/test.yml`](.github/workflows/test.yml)
- [`.github/workflows/benchmark.yml`](.github/workflows/benchmark.yml)
- [`.github/workflows/security.yml`](.github/workflows/security.yml)

## Examples

The [examples](examples) directory contains scenario-driven samples for:
- hello-component
- actor-supervision
- binary-rpc-replacement
- edge-device-sensor
- gpu-exec
- ai-agent-component

## Quick Start

1. Read the architecture docs in [docs](docs).
2. Run the workspace CI wrapper:

```sh
sh scripts/ci.sh
```

3. Review the SDK scaffolds under [sdks](sdks).
4. Make changes with tests and documentation updates together.

## Repository Layout

- [modules](modules): runtime, hardware, toolchain, and subsystem modules
- [sdks](sdks): generated-language SDK scaffolds
- [docs](docs): architecture, runtime, hardware, toolchain, developer, tutorial, and reference documentation
- [specs](specs): WAS v0.1 architecture contracts and invariants
- [tests](tests): component and integration tests
- [scripts](scripts): workspace automation wrappers
- [.github](.github): CI workflows and contribution templates

## Project Status

Implemented and test-validated foundations:
- runtime lifecycle and service registry primitives
- deterministic memory arena and quota primitives
- cooperative scheduler task execution path
- capability token authorization model
- WASM engine lifecycle contracts
- component load/link contracts with WIT world matching
- WIT parsing, canonical ABI mapping, and primitive codecs
- WASI host context with capability-gated storage access
- security revocation manager and resource-handle permission checks
- build/package/verify contracts and `.wvm` manifest serialization
- signing, verification, and trust registry gates
- bindgen stubs and canonical ABI helper scaffolds
- component tool lifecycle contracts
- deploy/update/rollback/migrate trust-gated package admission
- repository scripts and GitHub Actions workflow set
- SDK scaffolds for Zig, Rust, Go, C, Python, and JavaScript

## License

Wavium is intended to be released under [Apache License 2.0](LICENSE).

Apache 2.0 is a strong fit for infrastructure software because it supports broad adoption, includes an explicit patent grant, and aligns with the governance model used by major open-source systems projects.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow, testing requirements, and review expectations.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for near-term and longer-term project direction.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting and threat-model expectations.
