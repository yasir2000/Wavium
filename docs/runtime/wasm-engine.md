# WASM Engine

The WASM engine loads, validates, instantiates, executes, and destroys components.

Design goals:
- explicit instance lifecycle
- no hidden host dependencies
- predictable execution semantics
- compatibility with future interpreter, JIT, and AOT backends

The engine exists to execute portable component code, not to recreate a general-purpose VM.

## Related Documentation

- [Component Model](../architecture/component-model.md)
- [Execution Model](../architecture/execution-model.md)
- [Wavium Component Spec](../specifications/wavium-component-spec.md)