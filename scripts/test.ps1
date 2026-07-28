$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:ZIG_LOCAL_CACHE_DIR = "$PWD/zig-local-cache"
zig build test
