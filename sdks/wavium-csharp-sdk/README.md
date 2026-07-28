# wavium-csharp-sdk

C# SDK for Wavium runtime clients and generated bindings.

This SDK exposes the same capability-first Wavium runtime surface as the other language SDKs: resource access always flows through an explicit `CapabilityHandle`, and payloads are encoded with the same canonical ABI used by the runtime and `wavium-wit`.

## Contents

- `src/WaviumSdk.csproj` and `src/Wavium.cs`: SDK identity, `CapabilityHandle`, and canonical ABI codecs (`i32`, `bool`, length-prefixed `string`).
- `tests/WaviumSdk.Tests.csproj` and `tests/Program.cs`: a dependency-free console test runner (no test framework required).

## Building And Testing

```sh
dotnet run --project tests/WaviumSdk.Tests.csproj
```

## Related Documentation

- [SDK Generation](../../docs/toolchain/sdk-generation.md)
- [WIT Model](../../docs/architecture/wit-model.md)
- [Wavium SDK Registry](../../modules/wavium-sdk/src/lib.zig)
