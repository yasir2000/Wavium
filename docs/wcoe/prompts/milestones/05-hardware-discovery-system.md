# Prompt 05 - Hardware Discovery System


```text
Implement Wavium hardware discovery.

Goal:

Discover hardware without an operating system.


Support:

x86:

- ACPI
- PCI


ARM:

- Device Tree
- ACPI


RISC-V:

- Device Tree


Create:

devices/

├── discovery/
├── registry/
├── metadata/
└── topology/


The result should create:

Hardware Registry


Example:

CPU

Memory

NIC

Storage

GPU

Sensors


Expose discovered resources as capabilities.
```

