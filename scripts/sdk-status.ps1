$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
Get-ChildItem sdks | ForEach-Object { Write-Output $_.FullName }
