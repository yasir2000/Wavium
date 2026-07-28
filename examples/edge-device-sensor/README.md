# Edge Device Sensor Example

This example shows how an edge workload can model sensor access as an explicit capability instead of an ambient device file.

It is useful for board support and hardware-discovery discussions.

## What It Proves

- hardware access is capability-scoped
- a component can query a device without depending on an OS device file model
- board-specific behavior can still be represented with a stable interface

## Example Sensors

- temperature
- humidity
- generic fallback behavior