# Wavium Documentation Portal

Wavium documentation is organized as a technical reference set rather than a marketing README.

## Navigation
- [Vision](vision/project-vision.md)
- [Architecture](architecture/overview.md)
- [Runtime](runtime/wavium-core.md)
- [Hardware](hardware/bootloader.md)
- [Toolchain](toolchain/cli.md)
- [Developers](developers/getting-started.md)
- [Specifications](specifications/wavium-runtime-spec.md)
- [Tutorials](tutorials/hello-world.md)
- [Reference](reference/command-reference.md)
- [ADRs](adr/001-why-zig.md)

## Documentation Standard
Every page should state its scope, the subsystem it describes, and the invariants it relies on.

## Primary System Model
Application -> WASM Component -> WIT Interface Contract -> Wavium Runtime -> Hardware Capability Layer -> Physical Hardware

## Site Build

The documentation portal is configured through [mkdocs.yml](../mkdocs.yml) and uses text-based diagram sources under [docs/images](images).
