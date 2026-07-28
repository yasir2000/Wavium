# Write a WIT Interface

WIT is the contract surface for portable components.

Guidelines:
- describe stable interface boundaries
- keep types canonical and binary-friendly
- version interface changes carefully
- treat WIT as the source of truth for SDK generation

When in doubt, model the behavior in WIT before implementing runtime support.