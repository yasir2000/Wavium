# Device Model

Devices are represented as descriptors, capabilities, and ownership state.

## Core Concepts

- `DeviceDescriptor`: identity and metadata
- `DeviceCapability`: the rights attached to a device
- `DeviceOwner`: the subsystem responsible for lifecycle and policy
- `DeviceState`: discovered, active, suspended, or unavailable

## Examples

- storage devices expose block capabilities
- GPU devices expose compute capabilities
- network devices expose packet capabilities
- sensors expose read-only observation capabilities

The model avoids leaking implementation details that would tie components to one specific board or peripheral family.