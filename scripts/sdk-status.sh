#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
find sdks -maxdepth 2 -mindepth 1 | sort
