#!/usr/bin/env bash
# Placeholder docs build. The docs are plain Markdown under docs/ today; this hook
# is where a VitePress/Docusaurus build will live (see docs/public-roadmap.md).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Docs are plain Markdown under docs/. Nothing to build yet."
echo "Pages:"
ls -1 docs
