# Security Model

Wavium security is capability-based and explicit.

The model includes:
- component sandboxing
- memory isolation
- secure boot verification
- package signing and trust roots
- hardware access through capability handles only

Threat modeling is part of the architecture, not a postscript. The default posture is deny-by-default with explicit grant paths.