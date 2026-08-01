$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "[check] build.ps1 boot-verify-x86_64"
& "$PSScriptRoot/build.ps1" boot-verify-x86_64

Write-Host "[check] test.ps1 boot-verify-x86_64"
& "$PSScriptRoot/test.ps1" boot-verify-x86_64

Write-Host "[check] ci.ps1 boot-verify-x86_64"
& "$PSScriptRoot/ci.ps1" boot-verify-x86_64

if (Get-Command bash -ErrorAction SilentlyContinue) {
    Write-Host "[check] build.sh boot-verify-x86_64"
    bash ./scripts/build.sh boot-verify-x86_64

    Write-Host "[check] test.sh boot-verify-x86_64"
    bash ./scripts/test.sh boot-verify-x86_64

    Write-Host "[check] ci.sh boot-verify-x86_64"
    bash ./scripts/ci.sh boot-verify-x86_64
}
else {
    Write-Host "[check] bash not available, skipping shell wrapper checks"
}

Write-Host "[check] all available wrapper checks passed"
