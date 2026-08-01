# Prompt 06 - Hardware Abstraction Layer


```text
Create the Wavium Hardware Abstraction Layer.


Purpose:

Hide hardware details from WebAssembly Components.


Architecture:

Component

↓

WIT

↓

Capability

↓

HAL

↓

Driver

↓

Hardware


Create:


hal/

├── cpu/
├── storage/
├── network/
├── gpu/
├── gpio/
├── timer/
└── power/


Requirements:

- hardware-independent APIs
- capability-based access
- no direct hardware exposure
- driver abstraction


Generate WIT interfaces for HAL services.
```

