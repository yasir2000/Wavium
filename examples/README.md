# Wavium Examples

This directory contains scenario-driven samples that demonstrate the Wavium programming model in small, reviewable slices.

Each example is intentionally narrow and maps to one subsystem or workflow:

| Example | What it demonstrates |
| --- | --- |
| [hello-component](hello-component) | Smallest portable component boundary |
| [actor-supervision](actor-supervision) | Mailbox-driven actor supervision |
| [binary-rpc-replacement](binary-rpc-replacement) | Binary-first request/response exchange |
| [edge-device-sensor](edge-device-sensor) | Capability-scoped device access |
| [gpu-exec](gpu-exec) | Hardware capability-backed compute dispatch |
| [ai-agent-component](ai-agent-component) | Runtime-managed workflow component |

## Documentation Standard

Every example should explain:
- the subsystem it exercises
- the WIT contract it exposes
- the runtime capability it assumes
- the data flow from language source to component execution

## How To Use These Examples

Start with [hello-component](hello-component), then move to actor, hardware, and binary communication examples.
Use the examples as reference material when writing documentation, tutorials, and integration tests.