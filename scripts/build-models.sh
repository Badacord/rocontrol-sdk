#!/usr/bin/env bash
# Builds the distributable model files and a sourcemap.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
rojo build default.project.json --output build/RoControl.rbxm
rojo build default.project.json --output build/RoControl.rbxmx
rojo sourcemap default.project.json --output build/sourcemap.json
echo "Built build/RoControl.rbxm, build/RoControl.rbxmx, build/sourcemap.json"
