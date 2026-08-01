# Prompt 07 - Driver Framework


```text
Implement the Wavium driver framework.


Drivers are not kernel modules.

They are capability providers.


Architecture:


Driver

↓

WIT Capability

↓

Component Runtime


Create:


drivers/

├── framework/
├── registry/
├── lifecycle/
├── storage/
├── network/
└── devices/


Implement:

- driver registration
- driver loading
- driver lifecycle
- capability advertisement
- hardware binding


Use Zig interfaces.
```

