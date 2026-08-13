#!/usr/bin/env bash
#
# dsh-lan — revert the LAN-access patches from a local deepseek-harness checkout.
#
# Usage:
#   ./revert.sh /path/to/deepseek-harness
#   (if no path given, uses the current directory)
#
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSH_DIR="${1:-$PWD}"
PATCH="$PATCH_DIR/patches/dsh-lan.patch"

if [ ! -f "$DSH_DIR/package.json" ]; then
  echo "✗ $DSH_DIR/package.json not found — not a deepseek-harness checkout?" >&2
  exit 1
fi

if ! git -C "$DSH_DIR" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "⚠ patches are not applied (or the checkout has diverged). Nothing to revert."
  exit 0
fi

git -C "$DSH_DIR" apply --reverse "$PATCH"
echo "✓ Reverted. Rebuild the web frontend if you had built it:"
echo "    cd $DSH_DIR && pnpm run build:web"
