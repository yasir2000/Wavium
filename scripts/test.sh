#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"
zig build test
