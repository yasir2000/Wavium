# Prompt 30 - Future Many-Core & Heterogeneous Architecture


```text
Design Wavium to support heterogeneous computing.

Future hardware:

Big.LITTLE CPUs

GPUs

NPUs

DPUs

SmartNICs

FPGAs

AI accelerators

TPUs

Implement a generic execution target abstraction.

Applications request capabilities, not devices.

Example:

compute.execute()

The runtime schedules execution on the most appropriate processing unit.

Create architecture documents describing:

- heterogeneous scheduling
- accelerator discovery
- capability mapping
- execution migration
- future extensibility

Do not implement hardware-specific code yet; design extensible interfaces and abstractions.
```

## Parallel runtime vision

```text
                        Wavium Runtime
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
     Core 0                 Core 1                Core N
        │                      │                      │
  Local Scheduler       Local Scheduler      Local Scheduler
        │                      │                      │
  Local Actor Queue     Local Actor Queue    Local Actor Queue
        │                      │                      │
 Local Allocators      Local Allocators     Local Allocators
        │                      │                      │
        └─────────────── Work Stealing ──────────────┘
                               │
                  Lock-Free Messaging & Capabilities
                               │
                    Hardware Abstraction Layer
                               │
                  CPUs • GPUs • NPUs • SmartNICs
```

The end-state target is parallelism-by-default from embedded boards to multi-socket cloud servers while preserving actor + capability + component abstractions.
