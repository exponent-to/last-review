#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
touch build/.gdignore
sh scripts/run.sh --headless --editor --import
sh scripts/run.sh --headless --export-release macOS "$PWD/build/PRsPlease.zip"
ditto -xk build/PRsPlease.zip build
echo "Built $PWD/build/PRs please.app"
