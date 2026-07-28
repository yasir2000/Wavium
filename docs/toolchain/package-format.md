# Package Format

Wavium packages are designed to carry component bytes, metadata, capabilities, and trust material together.

A package should include:
- a versioned header
- metadata and dependencies
- component payloads
- capability declarations
- signatures or trust references

Package structure must remain stable enough to support long-term tooling and reproducible deployment.