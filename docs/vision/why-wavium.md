# Why Wavium

Wavium exists because modern software stacks still depend on operating systems as the primary abstraction boundary. That model works, but it introduces unnecessary layers for systems that want portability, security, and precise control over execution.

Wavium makes the component boundary first-class, so the same application model can target bare metal, embedded hardware, edge nodes, and cloud machines without changing the programming contract.

## Motivation

Wavium is useful where an OS-centric approach is too heavy, too opaque, or too tied to one target class.

## Why The Component Model Matters

- components are easier to isolate than native processes
- the contract boundary is machine-readable through WIT
- SDKs can be generated consistently across languages
- portability becomes a property of the contract instead of the deployment environment

## Why This Matters

This matters when the goals are:
- high performance
- predictable memory and startup behavior
- safer multi-tenant execution
- polyglot component development
- direct hardware bootstrap and control