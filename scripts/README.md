# Repository Scripts

Cross-platform wrappers for common Wavium workspace tasks.

Available commands:
- `test` runs the full Zig test suite with a local cache.
- `build` runs the root Zig build.
- `sdk-status` prints the SDK scaffold directories and key files.
- `ci` runs SDK status plus the full Zig test suite.
- `build boot-verify-x86_64` runs the Prompt 02 x86_64 boot verification flow via `boot/build.zig`.
- `test boot-verify-x86_64` runs the same Prompt 02 x86_64 boot verification flow from test wrappers.
- `ci boot-verify-x86_64` runs the same Prompt 02 x86_64 boot verification flow from CI wrappers.
- `check-boot-verify-wrappers` runs wrapper-level regression checks for all available boot verification entrypoints.
- `check-boot-preflight-workflow` validates reusable workflow/caller wiring for boot preflight checks.

Examples:

- Unix shell: `./scripts/build.sh boot-verify-x86_64`
- PowerShell: `./scripts/build.ps1 boot-verify-x86_64`
- Unix shell: `./scripts/test.sh boot-verify-x86_64`
- PowerShell: `./scripts/test.ps1 boot-verify-x86_64`
- Unix shell: `./scripts/ci.sh boot-verify-x86_64`
- PowerShell: `./scripts/ci.ps1 boot-verify-x86_64`
- Unix shell: `./scripts/check-boot-verify-wrappers.sh`
- PowerShell: `./scripts/check-boot-verify-wrappers.ps1`
- Unix shell: `./scripts/check-boot-preflight-workflow.sh`
- PowerShell: `./scripts/check-boot-preflight-workflow.ps1`

Optional override:

- `WAVIUM_ZIG_BIN` may be set to a specific Zig executable path.

Shared boot verify entrypoints:

- Unix shell: `./scripts/boot-verify.sh`
- PowerShell: `./scripts/boot-verify.ps1`

Note:

- `boot-verify-x86_64` intentionally bypasses the repository local Zig cache override in this environment to avoid stale step resolution for `boot/build.zig`.

Use the PowerShell scripts on Windows and the shell scripts on Unix-like systems.

CI integration:

- `.github/workflows/boot-wrapper-preflight.yml` is the reusable preflight workflow for wrapper checks.
- `.github/workflows/ci.yml`, `.github/workflows/test.yml`, and `.github/workflows/build.yml` call this reusable workflow.
- The preflight jobs are change-gated (run when `boot/**`, `scripts/**`, or the corresponding workflow file changes) and are blocking when triggered.