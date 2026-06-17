#!/usr/bin/env bash
# Runs the pure-logic test suite. Prefers `luau`, falls back to `lune`.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v luau >/dev/null 2>&1; then
	exec luau tests/run.luau
elif command -v lune >/dev/null 2>&1; then
	exec lune run tests/run.luau
else
	echo "Neither 'luau' nor 'lune' is installed. Run 'rokit install' first." >&2
	exit 1
fi
