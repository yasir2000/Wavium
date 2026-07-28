# ADR 004: No OS Design

Status: Accepted

Wavium intentionally avoids dependency on a general-purpose operating system to keep the execution model small, deterministic, and directly tied to hardware.

Consequences:
- boot and hardware responsibility move into the project
- the runtime owns the platform contract
- portability must be expressed through WIT and the HAL, not through OS APIs