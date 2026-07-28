# Security Policy

Wavium is built around capability-based security and explicit trust boundaries.

## Reporting Vulnerabilities
If you discover a vulnerability, do not open a public issue. Report it privately to the maintainers with:
- a short summary
- affected subsystem or module
- reproduction steps
- impact assessment
- suggested mitigation if available

## Security Philosophy
- No ambient authority.
- No hidden access paths.
- Capability checks at every resource boundary.
- Prefer deterministic, auditable security mechanisms.

## Threat Model
Assets:
- runtime integrity
- component isolation
- package signatures
- hardware capabilities
- boot trust anchors

Primary attack vectors:
- malicious components
- compromised build artifacts
- forged signatures
- capability escalation
- unsafe hardware access paths

Mitigations:
- signed packages
- explicit capability tokens
- sandboxed component execution
- secure boot verification
- trusted build and release pipeline