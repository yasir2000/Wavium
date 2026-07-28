# Design Philosophy

Wavium follows a strict separation between application logic, runtime services, and hardware control.

The design philosophy is intentionally infrastructure-grade:
- no hidden authority
- no ambient OS services
- no implicit allocation paths
- no text-first internal protocol assumptions
- no coupling to any single CPU or board family

The platform is meant to be auditable, portable, and small enough to run on hardware where a conventional cloud stack would be inappropriate.