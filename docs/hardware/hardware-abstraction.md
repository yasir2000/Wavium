# Hardware Abstraction

The hardware abstraction layer exposes devices through typed capabilities rather than OS device files.

It is responsible for:
- safe device access
- board-specific initialization
- capability mediation
- driver ownership boundaries

The HAL is the policy boundary between physical devices and component-level execution.