$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$zigPath = $env:WAVIUM_ZIG_BIN
if ([string]::IsNullOrWhiteSpace($zigPath)) {
    $zigPath = "C:\Users\yasir\zig-x86_64-windows-0.17.0-dev\zig.exe"
}

# Cache override is intentionally removed for this flow to avoid stale step
# resolution for boot/build.zig in this environment.
Remove-Item Env:ZIG_LOCAL_CACHE_DIR -ErrorAction SilentlyContinue
& $zigPath build --build-file boot/build.zig boot-verify-x86_64
exit $LASTEXITCODE
