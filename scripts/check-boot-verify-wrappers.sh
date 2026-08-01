#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

echo "[check] build.sh boot-verify-x86_64"
sh scripts/build.sh boot-verify-x86_64

echo "[check] test.sh boot-verify-x86_64"
sh scripts/test.sh boot-verify-x86_64

echo "[check] ci.sh boot-verify-x86_64"
sh scripts/ci.sh boot-verify-x86_64

if command -v powershell.exe >/dev/null 2>&1; then
  echo "[check] build.ps1 boot-verify-x86_64"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/build.ps1 boot-verify-x86_64

  echo "[check] test.ps1 boot-verify-x86_64"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/test.ps1 boot-verify-x86_64

  echo "[check] ci.ps1 boot-verify-x86_64"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/ci.ps1 boot-verify-x86_64
else
  echo "[check] powershell.exe not available, skipping PowerShell wrapper checks"
fi

echo "[check] all available wrapper checks passed"
