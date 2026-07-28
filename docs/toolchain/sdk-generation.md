# SDK Generation

SDK generation turns WIT contracts and canonical ABI rules into language-native bindings.

## Supported Targets

- Zig
- Rust
- Go
- C
- Python
- JavaScript
- Java
- C#
- PHP

## SDK Goals

- keep the contract surface identical across languages
- expose capability handles explicitly
- preserve binary-friendly types
- keep generated code small and readable

Generated SDKs should expose the same capability model while leaving room for small handwritten adapters around the generated surface.

## Related Documentation

- [WIT Model](../architecture/wit-model.md)
- [Write a WIT Interface](../developers/write-wit-interface.md)
- [API Reference](../reference/api-reference.md)