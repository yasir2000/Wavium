# Device Model

Devices are represented as descriptors, capabilities, and ownership state.

Examples:
- storage devices expose block capabilities
- GPU devices expose compute capabilities
- network devices expose packet capabilities

The model avoids leaking implementation details that would tie components to one specific board or peripheral family.