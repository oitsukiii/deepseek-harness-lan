#!/usr/bin/env bash
#
# dsh-lan — apply the LAN-access patches to a local deepseek-harness checkout.
#
# Usage:
#   ./apply.sh /path/to/deepseek-harness
#   (if no path given, uses the current directory)
#
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSH_DIR="${1:-$PWD}"

# ---- 0. sanity: is this really a deepseek-harness checkout? ----
if [ ! -f "$DSH_DIR/package.json" ]; then
  echo "✗ $DSH_DIR/package.json not found — not a deepseek-harness checkout?" >&2
  exit 1
fi
if ! grep -q '"@deepseek-ai/dsh-root"' "$DSH_DIR/package.json" 2>/dev/null; then
  echo "✗ $DSH_DIR does not look like the deepseek-harness root (missing @deepseek-ai/dsh-root)" >&2
  exit 1
fi

PATCH="$PATCH_DIR/patches/dsh-lan.patch"

# ---- 1. already applied? ----
if grep -q "Local patch: crypto.randomUUID" "$DSH_DIR/apps/web/src/main.ts" 2>/dev/null; then
  echo "⚠ patches already applied to $DSH_DIR (randomUUID polyfill found). Nothing to do."
  exit 0
fi

echo "[1/3] Checking patch applies cleanly ..."
git -C "$DSH_DIR" apply --check "$PATCH"
echo "      ok."

echo "[2/3] Applying patch ..."
git -C "$DSH_DIR" apply "$PATCH"
echo "      ok."

echo "[3/3] Ensuring build dependency 'unrun' (tsdown needs it) ..."
if ! ls "$DSH_DIR/node_modules/.pnpm" 2>/dev/null | grep -q '^unrun@'; then
  (cd "$DSH_DIR" && pnpm add -D unrun -w >/dev/null 2>&1 && echo "      unrun installed.") \
    || echo "      ! could not install unrun — if 'pnpm run build' later fails with 'Failed to import module \"unrun\"', run:  pnpm add -D unrun -w"
else
  echo "      unrun already present."
fi

echo ""
echo "✓ Patches applied. Next steps:"
echo ""
echo "  1) Rebuild the web frontend (the randomUUID polyfill lives in web assets):"
echo "       cd $DSH_DIR && pnpm run build:web"
echo ""
echo "  2) Start dsh bound to your LAN IP and trust that authority:"
echo "       pnpm dsh web --host <YOUR_LAN_IP> --trusted-host <YOUR_LAN_IP>"
echo "     e.g.  pnpm dsh web --host 192.168.1.100 --trusted-host 192.168.1.100"
echo ""
echo "  3) Open http://<YOUR_LAN_IP>:3080 from another device (Ctrl+F5 to bypass cache)."
echo ""
echo "  Revert anytime with:  $PATCH_DIR/revert.sh $DSH_DIR"
