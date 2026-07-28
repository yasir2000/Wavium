# Wavium SDKs

This directory contains language SDK scaffolds generated from Wavium WIT and canonical ABI contracts.

Shared registry:
- modules/wavium-sdk/src/lib.zig provides the canonical language-to-package mapping and directory names.

Current language targets:
- wavium-zig-sdk
- wavium-rust-sdk
- wavium-go-sdk
- wavium-c-sdk
- wavium-python-sdk
- wavium-js-sdk
- wavium-java-sdk
- wavium-csharp-sdk
- wavium-php-sdk

Each SDK is intended to expose the same capability-first Wavium runtime surface in the target language while keeping generated bindings and handwritten extensions separate.