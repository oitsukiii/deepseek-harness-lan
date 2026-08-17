#!/usr/bin/env bash
#
# deepseek-harness-lan — revert the LAN-access patches from a local deepseek-harness checkout.
#
# Usage:
#   ./revert.sh /path/to/deepseek-harness
#   (if no path given, uses the current directory)
#
set -euo pipefail

# ---- colors (TTY only) ----
if [ -t 1 ]; then
  C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[0;31m'
  C_CYAN=$'\033[0;36m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_RESET=''
fi
ok()   { echo -e "${C_GREEN}✓${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}⚠${C_RESET} $*"; }
err()  { echo -e "${C_RED}✗${C_RESET} $*"; }
info() { echo -e "${C_CYAN}ℹ${C_RESET} $*"; }

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSH_DIR="${1:-$PWD}"
PATCH="$PATCH_DIR/patches/deepseek-harness-lan.patch"

# Target version this patch set was written and verified against.
EXPECT_VERSION="0.1.0-rc.7"
EXPECT_COMMIT="99f6f02"

if [ ! -f "$DSH_DIR/package.json" ]; then
  err "$DSH_DIR/package.json not found — not a deepseek-harness checkout?"
  exit 1
fi

# Version hint (non-fatal: reverse apply itself is the real check)
dsh_version="$(node -e "console.log(require('$DSH_DIR/package.json').version)" 2>/dev/null || echo unknown)"
dsh_commit="$(git -C "$DSH_DIR" log --oneline -1 2>/dev/null | awk '{print $1}' || echo unknown)"
if [ "$dsh_version" != "$EXPECT_VERSION" ] || [ "$dsh_commit" != "$EXPECT_COMMIT" ]; then
  info "提示：当前 dsh $dsh_version ($dsh_commit)，补丁针对 $EXPECT_VERSION ($EXPECT_COMMIT)；"
  info "     反向应用若失败说明补丁状态与版本不符，可手动还原文件（见下方命令）。"
fi

if ! git -C "$DSH_DIR" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  warn "补丁未应用（或版本已分歧），无需还原。"
  info "若你确认打过补丁但还原失败，可手动还原："
  info "    git -C $DSH_DIR checkout apps/web/src/main.ts"
  info "    git -C $DSH_DIR checkout packages/bundle/web-app/src/startup.ts"
  info "    git -C $DSH_DIR checkout packages/client/connection/src/index.ts"
  info "    git -C $DSH_DIR checkout packages/host/webserver/src/index.ts"
  exit 0
fi

git -C "$DSH_DIR" apply --reverse "$PATCH"
ok "补丁已还原。若之前构建过前端，请重新构建:"
info "    cd $DSH_DIR && pnpm run build:web"
