# wavium-php-sdk

PHP SDK for Wavium runtime clients and generated bindings.

This SDK exposes the same capability-first Wavium runtime surface as the other language SDKs: resource access always flows through an explicit `CapabilityHandle`, and payloads are encoded with the same canonical ABI used by the runtime and `wavium-wit`.

Unlike the fixed-buffer APIs in some other SDKs, PHP strings are dynamically sized byte buffers, so the encode functions here return newly created strings instead of writing into a caller-supplied buffer. The wire format produced is identical.

## Contents

- `src/Wavium.php`: SDK identity, `CapabilityHandle`, and canonical ABI codecs (`i32`, `bool`, length-prefixed `string`).
- `tests/WaviumTest.php`: a dependency-free test script (no PHPUnit required).

## Building And Testing

```sh
php tests/WaviumTest.php
```

## Related Documentation

- [SDK Generation](../../docs/toolchain/sdk-generation.md)
- [WIT Model](../../docs/architecture/wit-model.md)
- [Wavium SDK Registry](../../modules/wavium-sdk/src/lib.zig)
