# Driver Framework

Drivers are expected to behave as first-class components rather than opaque kernel modules.

## Framework Goals

- registration and discovery
- resource ownership
- interrupt handling
- DMA access under policy
- testable lifecycle hooks
- component-native packaging and review

## Driver Lifecycle

1. discover
2. validate
3. initialize
4. operate
5. suspend or stop
6. release capabilities

Driver code must remain small, auditable, and capability-scoped.