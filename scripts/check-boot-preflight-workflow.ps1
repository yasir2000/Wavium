$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Require-Contains {
    param(
        [Parameter(Mandatory = $true)] [string] $File,
        [Parameter(Mandatory = $true)] [string] $Pattern,
        [Parameter(Mandatory = $true)] [string] $Description
    )

    if (-not (Select-String -Path $File -SimpleMatch $Pattern -Quiet)) {
        throw "[check] failed: $Description ($File)"
    }
}

Write-Host "[check] reusable preflight workflow exists"
if (-not (Test-Path ".github/workflows/boot-wrapper-preflight.yml")) {
    throw "[check] failed: missing .github/workflows/boot-wrapper-preflight.yml"
}

Write-Host "[check] reusable workflow has expected gate patterns"
Require-Contains -File ".github/workflows/boot-wrapper-preflight.yml" -Pattern "- 'boot/**'" -Description "boot path gate"
Require-Contains -File ".github/workflows/boot-wrapper-preflight.yml" -Pattern "- 'scripts/**'" -Description "scripts path gate"
Require-Contains -File ".github/workflows/boot-wrapper-preflight.yml" -Pattern "inputs.workflow_file" -Description "workflow-file path gate"
Require-Contains -File ".github/workflows/boot-wrapper-preflight.yml" -Pattern "sh scripts/check-boot-verify-wrappers.sh" -Description "shell preflight runner"
Require-Contains -File ".github/workflows/boot-wrapper-preflight.yml" -Pattern ".\scripts\check-boot-verify-wrappers.ps1" -Description "powershell preflight runner"

foreach ($workflow in @("ci", "test", "build")) {
    $file = ".github/workflows/$workflow.yml"
    Write-Host "[check] caller wiring in $file"
    Require-Contains -File $file -Pattern "uses: ./.github/workflows/boot-wrapper-preflight.yml" -Description "reusable workflow use"
    Require-Contains -File $file -Pattern "workflow_file: .github/workflows/$workflow.yml" -Description "caller workflow_file input"
}

Write-Host "[check] boot preflight workflow wiring is valid"