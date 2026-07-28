# AI Agent Component Example

This example shows the shape of a component that participates in a runtime-managed workflow with explicit state and binary messaging.

It is intentionally lightweight and avoids any model-specific assumptions.

## What It Proves

- component workflows can be modeled as deterministic steps
- the runtime can host higher-level orchestration without changing the application boundary
- workflow state remains visible and explicit

## Example Flow

plan -> execute -> verify