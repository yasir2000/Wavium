#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"

ZIG_BIN="${WAVIUM_ZIG_BIN:-zig}"

if [ "${1:-}" = "boot-verify-x86_64" ]; then
	sh scripts/boot-verify.sh
	exit $?
fi

"$ZIG_BIN" build
