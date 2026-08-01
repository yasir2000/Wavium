$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:ZIG_LOCAL_CACHE_DIR = "$PWD/zig-local-cache"

if ($args.Count -gt 0 -and $args[0] -eq "boot-verify-x86_64") {
	& "$PSScriptRoot/boot-verify.ps1"
	exit $LASTEXITCODE
}

zig build test
