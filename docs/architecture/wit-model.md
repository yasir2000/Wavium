# WIT Model

WIT defines the contract between components and the runtime. It is the API surface that replaces OS-facing assumptions with explicit interface definitions.

WIT is used for:
- type-safe interface contracts
- canonical ABI mapping
- generated SDKs
- hardware capability surfaces

Any long-lived public interface in Wavium should be represented in WIT before it is treated as stable.

## Related Documentation

- [Component Model](component-model.md)
- [Write a WIT Interface](../developers/write-wit-interface.md)
- [SDK Generation](../toolchain/sdk-generation.md)