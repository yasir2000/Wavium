# Create a Component

A Wavium component typically follows this flow:

Language -> WASM compilation -> WIT interface -> package -> deploy

```mermaid
flowchart TD
    Lang[Language Source] --> Wasm[WASM Compilation]
    Wasm --> Wit[WIT Interface]
    Wit --> Pkg[Package]
    Pkg --> Deploy[Deploy]
```

Components should be kept portable and free of OS assumptions.