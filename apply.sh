#!/usr/bin/env bash
#
# deepseek-harness-lan — apply the LAN-access patches to a local deepseek-harness checkout.
#
# Usage:
#   ./apply.sh /path/to/deepseek-harness
#   (if no path given, uses the current directory)
#
# Behavior:
#   - Real-time step-by-step output (progress, warnings, errors).
#   - Colors are used only when stdout is a TTY; redirected output is plain text.
#   - Version mismatch warns but continues; DSH_LAN_STRICT=1 aborts instead.
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

# Target version this patch set was written and verified against.
EXPECT_VERSION="0.1.0-rc.7"
EXPECT_COMMIT="99f6f02"

# ---- 1. sanity: is this really a deepseek-harness checkout? ----
if [ ! -f "$DSH_DIR/package.json" ]; then
  err "$DSH_DIR/package.json not found — not a deepseek-harness checkout?"
  exit 1
fi
if ! grep -q '"@deepseek-ai/dsh-root"' "$DSH_DIR/package.json" 2>/dev/null; then
  err "$DSH_DIR does not look like the deepseek-harness root (missing @deepseek-ai/dsh-root)"
  exit 1
fi

# ---- 2. version check: warn (or abort) when the checkout differs ----
dsh_version="$(node -e "console.log(require('$DSH_DIR/package.json').version)" 2>/dev/null || echo unknown)"
dsh_commit="$(git -C "$DSH_DIR" log --oneline -1 2>/dev/null | awk '{print $1}' || echo unknown)"

if [ "$dsh_version" != "$EXPECT_VERSION" ] || [ "$dsh_commit" != "$EXPECT_COMMIT" ]; then
  warn "版本不匹配警告"
  [ "$dsh_version" != "$EXPECT_VERSION" ] && warn "    package.json version: 期望 $EXPECT_VERSION，实际 $dsh_version"
  [ "$dsh_commit" != "$EXPECT_COMMIT" ] && warn "    git commit:            期望 $EXPECT_COMMIT，实际 $dsh_commit"
  warn "    补丁针对 $EXPECT_VERSION ($EXPECT_COMMIT) 编写并验证；其他版本可能应用失败。"
  warn "    继续尝试（git apply --check 会兜底），失败请按 README「兼容性」适配。"
  if [ "${DSH_LAN_STRICT:-0}" = "1" ]; then
    err "DSH_LAN_STRICT=1 已设置，因版本不匹配中止。"
    exit 1
  fi
else
  ok "[1/4] 版本校验通过: dsh $dsh_version ($dsh_commit) 与补丁目标一致"
fi

PATCH="$PATCH_DIR/patches/deepseek-harness-lan.patch"

# ---- 3. already applied? ----
if grep -q "Local patch: crypto.randomUUID" "$DSH_DIR/apps/web/src/main.ts" 2>/dev/null; then
  warn "补丁已应用（检测到 randomUUID polyfill），无需重复操作。"
  exit 0
fi

# ---- 4. check + apply ----
info "[2/4] 检查补丁能否干净应用 ..."
if ! git -C "$DSH_DIR" apply --check "$PATCH" 2>&1; then
  err "补丁应用检查失败——你的 dsh 版本可能与本补丁目标 ($EXPECT_VERSION) 不符。"
  err "请查看上方具体冲突，或按 README「兼容性」适配新版本；当前未做任何修改。"
  exit 1
fi
ok "[2/4] 补丁检查通过"

info "[3/4] 应用补丁 ..."
git -C "$DSH_DIR" apply "$PATCH"
ok "[3/4] 补丁应用成功"

# ---- 5. build dependency ----
info "[4/4] 检查构建依赖 unrun（tsdown 需要）..."
if ! compgen -G "$DSH_DIR/node_modules/.pnpm/unrun@*" >/dev/null; then
  if (cd "$DSH_DIR" && pnpm add -D unrun -w >/dev/null 2>&1); then
    ok "[4/4] unrun 已安装"
  else
    warn "[4/4] unrun 安装失败——若后续 build 报 'Failed to import module \"unrun\"'，请手动执行: pnpm add -D unrun -w"
  fi
else
  ok "[4/4] unrun 已存在"
fi

echo ""
ok "补丁应用完成！后续步骤："
echo ""
info "  1) 重新构建前端（randomUUID polyfill 在 web 产物里）:"
echo "       cd $DSH_DIR && pnpm run build"
echo ""
info "  2) 绑定局域网 IP 并信任该入口启动:"
echo "       pnpm dsh web --host <局域网IP> --trusted-host <局域网IP>"
echo "       例:   pnpm dsh web --host 192.168.1.100 --trusted-host 192.168.1.100"
echo ""
info "  3) 在其他设备打开 http://<局域网IP>:3080 （建议 Ctrl+F5 强制刷新）"
echo ""
info "  还原: $PATCH_DIR/revert.sh $DSH_DIR"
