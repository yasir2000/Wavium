# Hardware Architecture

Hardware in Wavium is a first-class subsystem rather than a bag of drivers.

The hardware architecture includes:
- boot framework
- HAL
- discovery and registry
- driver components
- board support packages
- secure boot and trust roots

```mermaid
flowchart LR
    Boot[Bootloader] --> HAL[Hardware Abstraction Layer]
    HAL --> Discovery[Device Discovery]
    Discovery --> Drivers[Driver Components]
    Drivers --> Capabilities[Capability Registry]
    Capabilities --> Runtime[Wavium Runtime]
```

## Related Documentation

- [Bootloader](../hardware/bootloader.md)
- [Hardware Abstraction](../hardware/hardware-abstraction.md)
- [Wavium Hardware Spec](../specifications/wavium-hardware-spec.md)
