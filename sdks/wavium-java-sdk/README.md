# wavium-java-sdk

Java SDK for Wavium components, drivers, and runtime clients.

This SDK exposes the same capability-first Wavium runtime surface as the other language SDKs: resource access always flows through an explicit `CapabilityHandle`, and payloads are encoded with the same canonical ABI used by the runtime and `wavium-wit`.

## Contents

- `src/main/java/io/wavium/sdk/Wavium.java`: SDK identity, `CapabilityHandle`, and canonical ABI codecs (`i32`, `bool`, length-prefixed `string`).
- `src/test/java/io/wavium/sdk/WaviumTest.java`: a dependency-free test runner (no build tool required).

## Building And Testing

```sh
javac -d out src/main/java/io/wavium/sdk/Wavium.java src/test/java/io/wavium/sdk/WaviumTest.java
java -cp out io.wavium.sdk.WaviumTest
```

> If your `PATH` resolves `java` to an older JRE than the `javac` used to compile, run the class with the matching JDK's `java` executable explicitly (e.g. the JDK 17+ install used for `javac`).

## Related Documentation

- [SDK Generation](../../docs/toolchain/sdk-generation.md)
- [WIT Model](../../docs/architecture/wit-model.md)
- [Wavium SDK Registry](../../modules/wavium-sdk/src/lib.zig)
