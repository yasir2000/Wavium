# Hardware Example

This tutorial demonstrates how a component or driver acquires a hardware capability through the runtime and uses it without bypassing the trust model.

## Prerequisites

- understanding of the hardware architecture docs
- a target board or simulator profile
- a component or driver that can request a capability

## Tutorial Flow

```mermaid
flowchart TD
	Request[Capability Request] --> Runtime[Runtime Policy]
	Runtime --> Handle[Capability Handle]
	Handle --> Device[Hardware Device]
	Device --> Result[Observed Result]
```

1. identify the hardware resource you want to access.
2. request the corresponding capability from the runtime.
3. obtain a safe handle or device descriptor.
4. interact with the device through the approved interface.
5. confirm the component never bypasses the trust model.

## Expected Behavior

- capability acquisition is explicit
- hardware interaction is constrained by policy
- board-aware behavior works without OS dependencies
- runtime ownership remains visible in the access path

## Learning Outcome

You should understand capability acquisition, hardware interaction under policy, and board-aware behavior without OS dependencies.