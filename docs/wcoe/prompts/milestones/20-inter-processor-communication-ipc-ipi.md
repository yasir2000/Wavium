# Prompt 20 - Inter-Processor Communication (IPC/IPI)


```text
Implement inter-core communication.

Support:

- Inter-Processor Interrupts (IPI)
- Remote actor wake-up
- Cross-core scheduling
- Cross-core memory synchronization
- Remote mailbox notification

Repository:

runtime/ipi/

Support:

x86 APIC

ARM GIC

RISC-V CLINT/SBI

Provide architecture abstraction.

Implement:

send()
broadcast()
multicast()
barrier()

Create benchmark suite.
```

