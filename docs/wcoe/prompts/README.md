# Wavium Engineering Prompt Suite

This folder contains milestone-scoped prompts for building Wavium in architecture-safe increments.

## Why this exists

Wavium is a deep systems project. Prompting for "build everything" creates architectural drift and hidden dependencies. The suite enforces:

- one subsystem per prompt
- strict implementation order
- architecture contract discipline
- explicit no-POSIX/no-libc/no-kernel constraints

## How to use

1. Run prompts in numeric order.
2. Keep each output focused on scaffolding/behavior required by that milestone only.
3. Validate milestone exit criteria before moving forward.
4. Require tests and docs changes per milestone.

## Documents

- [Wavium Engineering Prompt Suite v1](wavium-engineering-prompt-suite-v1.md)
- [Milestone Prompt Files](milestones/README.md)
