# Create a Driver

Drivers in Wavium are expected to be small, capability-scoped components.

The recommended flow is:
- model the hardware capability
- define the WIT interface
- implement the driver component
- validate the lifecycle in simulation
- ship only after the trust and security model is satisfied