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

# Target version this patch set was written and verified against.
EXPECT_VERSION="0.1.0-rc.5"
EXPECT_COMMIT="47f9438"

if [ ! -f "$DSH_DIR/package.json" ]; then
  echo "✗ $DSH_DIR/package.json not found — not a deepseek-harness checkout?" >&2
  exit 1
fi

# Version hint (non-fatal: reverse apply itself is the real check)
dsh_version="$(node -e "console.log(require('$DSH_DIR/package.json').version)" 2>/dev/null || echo unknown)"
dsh_commit="$(git -C "$DSH_DIR" log --oneline -1 2>/dev/null | awk '{print $1}' || echo unknown)"
if [ "$dsh_version" != "$EXPECT_VERSION" ] || [ "$dsh_commit" != "$EXPECT_COMMIT" ]; then
  echo "ℹ 提示：当前 dsh $dsh_version ($dsh_commit)，补丁针对 $EXPECT_VERSION ($EXPECT_COMMIT)；"
  echo "   反向应用若失败说明补丁状态与版本不符，可手动 git checkout 相关文件还原。"
fi

if ! git -C "$DSH_DIR" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "⚠ patches are not applied (or the checkout has diverged). Nothing to revert."
  echo "  若你确认打过补丁但还原失败，可手动还原以下文件："
  echo "    git -C $DSH_DIR checkout apps/web/src/main.ts"
  echo "    git -C $DSH_DIR checkout packages/bundle/web-app/src/startup.ts"
  echo "    git -C $DSH_DIR checkout packages/client/connection/src/index.ts"
  echo "    git -C $DSH_DIR checkout packages/host/webserver/src/index.ts"
  exit 0
fi

git -C "$DSH_DIR" apply --reverse "$PATCH"
echo "✓ Reverted. Rebuild the web frontend if you had built it:"
echo "    cd $DSH_DIR && pnpm run build:web"
