#!/usr/bin/env bash
# Publishes the package to the Wally registry. Requires WALLY_TOKEN in the env.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${WALLY_TOKEN:-}" ]]; then
	echo "WALLY_TOKEN is not set." >&2
	exit 1
fi

wally login --token "$WALLY_TOKEN"
wally publish
