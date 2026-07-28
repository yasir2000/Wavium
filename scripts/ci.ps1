$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:ZIG_LOCAL_CACHE_DIR = "$PWD/zig-local-cache"
& "$PSScriptRoot/sdk-status.ps1"
zig build test
