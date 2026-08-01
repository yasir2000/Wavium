#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

require_contains() {
  file="$1"
  pattern="$2"
  description="$3"
  if ! grep -F -q -- "$pattern" "$file"; then
    echo "[check] failed: $description ($file)"
    exit 1
  fi
}

echo "[check] reusable preflight workflow exists"
if [ ! -f .github/workflows/boot-wrapper-preflight.yml ]; then
  echo "[check] failed: missing .github/workflows/boot-wrapper-preflight.yml"
  exit 1
fi

echo "[check] reusable workflow has expected gate patterns"
require_contains ".github/workflows/boot-wrapper-preflight.yml" "- 'boot/**'" "boot path gate"
require_contains ".github/workflows/boot-wrapper-preflight.yml" "- 'scripts/**'" "scripts path gate"
require_contains ".github/workflows/boot-wrapper-preflight.yml" "inputs.workflow_file" "workflow-file path gate"
require_contains ".github/workflows/boot-wrapper-preflight.yml" "sh scripts/check-boot-verify-wrappers.sh" "shell preflight runner"
require_contains ".github/workflows/boot-wrapper-preflight.yml" ".\\scripts\\check-boot-verify-wrappers.ps1" "powershell preflight runner"

for workflow in ci test build; do
  file=".github/workflows/$workflow.yml"
  echo "[check] caller wiring in $file"
  require_contains "$file" "uses: ./.github/workflows/boot-wrapper-preflight.yml" "reusable workflow use"
  require_contains "$file" "workflow_file: .github/workflows/$workflow.yml" "caller workflow_file input"
done

echo "[check] boot preflight workflow wiring is valid"