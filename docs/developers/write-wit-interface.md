# Write a WIT Interface

WIT is the contract surface for portable components.

## Guidelines

- describe stable interface boundaries
- keep types canonical and binary-friendly
- version interface changes carefully
- treat WIT as the source of truth for SDK generation
- prefer small interfaces that map cleanly to runtime capabilities

## Good Practice

If behavior is meant to be shared across languages, put it in WIT before writing language-specific bindings.

When in doubt, model the behavior in WIT before implementing runtime support.