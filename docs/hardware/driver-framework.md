# Driver Framework

Drivers are expected to behave as first-class components rather than opaque kernel modules.

The framework should support:
- registration and discovery
- resource ownership
- interrupt handling
- DMA access under policy
- testable lifecycle hooks

Driver code must remain small, auditable, and capability-scoped.