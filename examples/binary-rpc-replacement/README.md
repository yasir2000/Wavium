# Binary RPC Replacement Example

This example demonstrates the Wavium preference for binary-first communication instead of HTTP or JSON.

The payload flow uses a typed message and a WIT contract to represent a small request/response exchange.

## What It Proves

- binary payloads are the default internal transport form
- request/response semantics do not require HTTP
- component interfaces can remain small and explicit

## Runtime Model

```mermaid
flowchart LR
	Client[Client] --> Bytes[Binary Payload]
	Bytes --> Component[WASM Component]
	Component --> Bytes
	Bytes --> Client
```