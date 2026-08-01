#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

ZIG_BIN="${WAVIUM_ZIG_BIN:-zig}"

# Cache override is intentionally removed for this flow to avoid stale step
# resolution for boot/build.zig in this environment.
unset ZIG_LOCAL_CACHE_DIR
PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" "$ZIG_BIN" build --build-file boot/build.zig boot-verify-x86_64
