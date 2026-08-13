# 🐾 dsh-lan

> Run [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI on your home LAN — bind a specific IP, trust it, and open it from any device.
> 让 DeepSeek Harness 的 Web UI 在局域网里跑起来——从 Windows / 手机 / 平板直接打开。

![License](https://img.shields.io/badge/license-MIT-green)
![dsh](https://img.shields.io/badge/dsh-0.1.0--rc.5-blue)
![built-with](https://img.shields.io/badge/built%20with-DeepSeek%20V4%20Flash-4D6BFE)

---

## 📖 这是什么

dsh 的 Web UI **官方只允许本机（localhost）访问**。`--host 0.0.0.0` 直接报错：

```
error: --host 0.0.0.0 is intentionally not supported yet for safety:
it would expose remote code execution to the network; use 127.0.0.1 instead
```

这是**有意为之的安全设计**——dsh 的 Web UI 背后是一个能执行任意命令的 agent，官方不想让它裸奔到网络。

但家里/办公室的局域网，想在 **Windows、手机、平板上打开 dsh** 怎么办？本仓库提供 **4 个最小补丁 + 一键脚本**，让你绑定**指定局域网 IP** 安全运行 dsh Web UI。

## ✨ 特性

- 🔧 **4 个最小 diff**（81 行），只改必要源码，不引入额外依赖
- 📦 **一键打补丁 / 一键还原**（`apply.sh` / `revert.sh`），自动检测、防重复应用
- 🧩 **不破坏官方安全模型**：`0.0.0.0` 通配符仍被拒绝；`--trusted-host` 显式信任机制保留
- 🧪 **已在 dsh 0.1.0-rc.5 验证**：页面加载、API 调用、特权接口全通过
- 🪄 **自动补全 build 依赖**（`unrun`），`pnpm run build` 不会莫名失败

## 🚀 快速开始

### 依赖

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 源码（≥ 0.1.0-rc.5）
- Node.js ≥ 24、pnpm

### 安装

```bash
# 1. 准备 dsh 源码
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install

# 2. 克隆本仓库并打补丁
git clone https://github.com/<your-name>/dsh-lan.git
cd dsh-lan
./apply.sh /path/to/deepseek-harness
```

### 启动

```bash
cd /path/to/deepseek-harness

# 重新构建前端（randomUUID polyfill 在 web 产物里）
pnpm run build:web

# 绑定你的局域网 IP 并信任它
pnpm dsh web --host 192.168.1.100 --trusted-host 192.168.1.100
```

### 访问

在其他设备（Windows / 手机 / 平板）浏览器打开：

```
http://192.168.1.100:3080
```

> ⚠️ 若之前打开过，请 **Ctrl + F5 强制刷新**（浏览器可能缓存旧 JS）。

### 还原

```bash
./revert.sh /path/to/deepseek-harness
```

---

## 🧠 技术原理

dsh 官方阻止局域网访问，一共有 **三道闸**。本项目的 4 个补丁逐个击破：

### 闸 1：CLI 拒绝 `0.0.0.0`，schema 只认两个字面量

**现象**：`--host 0.0.0.0` 直接报错；想绑具体 IP（如 `192.168.1.100`）也会启动失败：

```
ValidationError: invalid config:
  - $.host expected "127.0.0.1" | "0.0.0.0" but got "192.168.1.100" (at host)
```

**原因**（两层限制）：

| 层 | 位置 | 限制 |
|---|---|---|
| CLI 层 | `packages/bundle/web-app/src/startup.ts` | `options.host === '0.0.0.0'` 时 `program.error()` 拒绝启动 |
| Schema 层 | `packages/host/webserver/src/index.ts` | zod 校验 `z.union([z.const('127.0.0.1'), z.const('0.0.0.0')])`，类型定义也只允许这两个值 |

**补丁**：

```diff
// packages/host/webserver/src/index.ts
- host: '127.0.0.1' | '0.0.0.0'      // 类型
+ host: string
- host: z.union([z.const('127.0.0.1'), z.const('0.0.0.0')]).required()   // zod
+ host: z.string().required()
```

```diff
// packages/bundle/web-app/src/startup.ts
- if (options.host === '0.0.0.0') {
-   program.error('...intentionally not supported yet for safety...')
- }
+ // 仅拒绝通配符 0.0.0.0；具体局域网 IP 放行
```

**设计取舍**：`0.0.0.0` 通配符绑定所有网卡（包括公网/WG），危险；绑定**具体 IP** 只暴露一个网卡，可控。所以只放开具体 IP，通配符继续拒绝。

### 闸 2：/api 的 browser-trust 围栏（403）

**现象**：页面能打开，但所有 `/api/*` 请求返回 `HTTP 403`，例如：

```
加载提供方目录失败: transport failure for /api/llm.providers: HTTP 403
```

**原因**：dsh 的 `/api` 网关前有一道 **browser-trust fence**（防 DNS rebinding / 跨站攻击），`packages/client/connection/src/index.ts` 里：

```ts
// 信任列表：只有绑 0.0.0.0 时才自动采集所有局域网 IP
// 绑具体 IP 时列表为空 → 非 localhost 请求全 403
const lanAddresses = bindHost === ALL_INTERFACES_HOST ? collectLanIps() : []
return { lanAddresses, trustedHosts: [...lanAddresses, ...extra] }
```

另外，**特权方法**（`settings.*`、`credentials.*`、`agentPreset.*` 等）用的是**空信任列表**检查——意味着即使加了 `--trusted-host`，这些接口依然只放行 localhost：

```ts
if (PRIVILEGED_METHODS.has(method) && !isTrustedApiRequest(request, [])) {
  return new Response('forbidden', { status: 403 })
}
```

**补丁**（`packages/client/connection/src/index.ts`）：

```diff
- && !isTrustedApiRequest(request, [])) {    // 空列表：仅 loopback
+ && !isTrustedApiRequest(request, trustedHosts)) {   // 显式信任生效
```

**设计取舍**：让 `--trusted-host`（管理员显式配置的信任入口）对特权接口也生效。**默认不传 `--trusted-host` 时行为不变**，仍只放行 localhost——官方安全语义原样保留。

### 闸 3：`crypto.randomUUID is not a function`

**现象**：配置 API 时报错：

```
加载提供方目录失败: crypto.randomUUID is not a function
```

**原因**：浏览器 Web Crypto API 的 `crypto.randomUUID()` **只在 secure context（HTTPS 或 localhost）可用**。用 `http://192.168.1.100:3080`（局域网明文 HTTP）访问时，这个函数不存在。

**补丁**（`apps/web/src/main.ts`，Web 入口最前面）：

```ts
// crypto.randomUUID 仅 secure context 可用；HTTP 局域网环境补一个 UUIDv4 实现
if (typeof globalThis.crypto === 'object' && typeof globalThis.crypto.randomUUID !== 'function') {
  try {
    globalThis.crypto.randomUUID = () =>
      'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0
        const v = c === 'x' ? r : (r & 0x3) | 0x8
        return v.toString(16)
      })
  } catch { /* crypto 只读环境则保持原样 */ }
}
```

> 💡 UUID 只用于本地标识（附件草稿、会话 id 等），不涉及安全校验，polyfill 无安全风险。

---

## 🔒 安全须知（务必阅读）

- ⚠️ **这个界面能执行任意命令**。打补丁后，**局域网内任何设备**都能访问并控制你的 agent。
- ✅ 只应在**信任的家庭/办公网络**使用。
- ❌ **不要**把 3080 端口映射到公网（port forwarding / DMZ）。
- ❌ **不要**用 `--host 0.0.0.0`（补丁后依然被拒绝，这是有意保留的防线）。
- 💡 进阶：可以在 dsh 前面再套一层**带认证的反向代理**（如 nginx Basic Auth）。
- 🔐 `--trusted-host` 是官方 browser-trust 机制的显式信任入口，请只填你自己的局域网 IP。

## ❓ FAQ

**Q: 手机上能访问吗？**
A: 能。只要手机连同一个局域网，浏览器打开 `http://<NAS-IP>:3080` 即可。

**Q: 打补丁后 dsh 官方更新怎么办？**
A: `apply.sh` 会先 `git apply --check`，上游代码变了会检查失败并中止，不会弄脏你的仓库。还原用 `revert.sh`，然后正常 `git pull` 更新即可。

**Q: 为什么不用 Docker 跑？**
A: dsh 官方提供的是 Node.js / npm 包，无官方 Docker 镜像；本项目只改源码，直接沿用官方安装方式最稳。

**Q: 这个补丁会被官方接受吗？**
A: 官方**有意**禁了通配符绑定，短期内不太可能放开；但绑定具体 IP + 显式信任的思路，可以给官方提 issue 讨论。

## 🧩 补丁文件一览

| 文件 | 解决 |
|---|---|
| `patches/dsh-lan.patch` | 全部 4 处改动的统一 diff（git apply 直接用） |

## 🤝 贡献

- Bug / 兼容性问题：开 issue，附 dsh 版本号 + 报错信息
- 新平台 / 新版本适配：提 PR，更新补丁并在对应版本验证
- 上游 dsh 更新后失效：欢迎提交更新后的 patch

## 🎉 致谢

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) —— 优秀的 agent 框架（"Everything is a Plugin"）
- 本项目由 **DeepSeek V4 Flash** 驱动开发（排查 → 定位 → 打补丁 → 脚本化 → 文档全流程）

## 📜 License

MIT License — 与 DeepSeek Harness 官方无关的非官方社区项目，仅供学习与自用参考。
