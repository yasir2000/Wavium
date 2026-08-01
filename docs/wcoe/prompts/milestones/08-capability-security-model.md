# Prompt 08 - Capability Security Model


```text
Implement Wavium capability security.


Replace:

syscalls

permissions

kernel privileges


with:

Capabilities.


Architecture:


Component

↓

Capability Token

↓

Policy Engine

↓

Resource


Implement:

security/

├── capability/
├── identity/
├── policy/
├── verification/
└── audit/


Features:

- least privilege
- capability delegation
- revocation
- isolation
- resource ownership


Create security specification documentation.
```

