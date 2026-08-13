# dsh-lan · 让 DeepSeek Harness 在局域网跑起来

> Run [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI on your home LAN — bind a specific IP, trust it, and open it from any device.

dsh 的 Web UI 默认**只允许本机（localhost）访问**：`--host 0.0.0.0` 会被直接拒绝（官方安全设计——这个界面背后是能执行任意命令的 agent，不能让它裸奔到网络上）。但家里局域网想用 Windows / 手机 / 平板打开 dsh 怎么办？

这个仓库提供 **4 个最小补丁 + 一键脚本**，让你在**指定局域网 IP** 上安全地运行 dsh Web UI。

---

## ✨ 解决了什么

| 现象 | 原因 | 补丁 |
|---|---|---|
| `--host 0.0.0.0` 被拒绝，`--host 192.168.2.102` 报 schema 校验失败 | CLI 封死通配符，webserver schema 只接受 `127.0.0.1` / `0.0.0.0` | `packages/host/webserver` + `packages/bundle/web-app` |
| 浏览器打开 `/api/*` 全部 **HTTP 403** | browser-trust 围栏（防 DNS rebinding）：绑具体 IP 时信任列表为空 | `packages/client/connection`（特权方法也认 `--trusted-host`） |
| 配置 API 报 `crypto.randomUUID is not a function` | Web Crypto API 只在 **HTTPS / localhost** 可用，局域网 HTTP 没有 | `apps/web/src/main.ts`（UUIDv4 polyfill） |

## 🚀 快速开始

```bash
# 1. 准备好 dsh 源码
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install

# 2. 打补丁（clone 本仓库，脚本里传入 dsh 路径）
git clone https://github.com/<your-name>/dsh-lan.git
cd dsh-lan
./apply.sh /path/to/deepseek-harness

# 3. 构建 + 启动（换成你自己的局域网 IP）
cd /path/to/deepseek-harness
pnpm run build:web
pnpm dsh web --host 192.168.1.100 --trusted-host 192.168.1.100

# 4. 局域网其他设备打开（注意 Ctrl+F5 强制刷新）
#    http://192.168.1.100:3080
```

还原：`./revert.sh /path/to/deepseek-harness`

## 🧩 补丁明细

| 文件 | 改动 |
|---|---|
| `packages/host/webserver/src/index.ts` | host schema 类型与 zod 校验从 `'127.0.0.1'\|'0.0.0.0'` 放宽为任意字符串 |
| `packages/bundle/web-app/src/startup.ts` | CLI 允许**具体 IP**（`0.0.0.0` 通配符仍拒绝，避免暴露到所有网卡） |
| `apps/web/src/main.ts` | `crypto.randomUUID` polyfill（HTTP 局域网环境） |
| `packages/client/connection/src/index.ts` | 特权接口（settings/credentials/agentPreset 等）的信任检查改用 `trustedHosts`，显式配置的 `--trusted-host` 生效 |

> `pnpm run build` 需要 `unrun`（tsdown 的 optional peer），脚本会自动补装；装不了就手动 `pnpm add -D unrun -w`。

## ⚠️ 安全须知（重要，请读完）

- **这个界面能执行任意命令**。打补丁后，**局域网内任何设备**都能访问并控制你的 agent——请只在**信任的家庭/办公网络**使用。
- **不要**把 3080 端口映射到公网、**不要**用 `--host 0.0.0.0`（通配符仍被拒绝是有意为之）。
- `--trusted-host` 是 dsh 官方的 browser-trust 机制，本补丁只是让显式信任的入口对特权接口也生效；**默认（不传 `--trusted-host`）行为不变**，仍只放行 localhost。
- 如果担心，可以在 dsh 前再套一层带认证的反向代理。

## 🧪 兼容性

- 在 `deepseek-harness` **0.1.0-rc.5**（`47f9438`）上验证通过。
- 上游更新后 patch 可能失效——`apply.sh` 会先 `git apply --check`，失败即中止，不会弄脏你的仓库；`revert.sh` 一键还原。

## 📜 License

MIT — 与 DeepSeek Harness 无关的非官方项目，仅供学习与自用参考。
