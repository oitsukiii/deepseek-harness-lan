# 🐾 deepseek-harness-lan

**English** | [简体中文](README.zh-CN.md)

> Run [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI on your home LAN — bind a specific IP, trust it, and open it from any device.

![License](https://img.shields.io/badge/license-MIT-green)
![dsh](https://img.shields.io/badge/dsh-0.1.1--rc.2-blue)
![built-with](https://img.shields.io/badge/built%20with-DeepSeek%20V4%20Flash-4D6BFE)

> **🎯 Target version: dsh `0.1.1-rc.2` (commit `b150a55`)** — the patch is written and verified against this version; other versions may break (see [🧩 Compatibility](#-compatibility)).

---

## 📖 What is this

dsh's Web UI is **officially restricted to localhost access only**. `--host 0.0.0.0` fails immediately:

```
error: --host 0.0.0.0 is intentionally not supported yet for safety:
it would expose remote code execution to the network; use 127.0.0.1 instead
```

This is a **deliberate security design** — the dsh Web UI sits on top of an agent that can execute arbitrary commands, and the official project does not want it exposed to the network.

But what if you want to open dsh from **Windows, phones, or tablets** on your home/office LAN? This repository provides **4 minimal patches + one-click scripts** that let you bind a **specific LAN IP** and run the dsh Web UI safely.

## ✨ Features

- 🔧 **4 minimal diffs** (81 lines) — only the necessary source changes, no extra dependencies
- 📦 **One-click apply / revert** (`apply.sh` / `revert.sh`) — auto-detection, duplicate-application guard
- 🧩 **Does not break the official security model**: the `0.0.0.0` wildcard is still rejected; the `--trusted-host` explicit trust mechanism is preserved
- 🧪 **Verified on dsh 0.1.1-rc.2**: page load, API calls, and privileged endpoints all pass
- 🪄 **Auto-installs the missing build dependency** (`unrun`) so `pnpm run build` doesn't fail mysteriously

## 🚀 Quick Start

### From zero to running (6 steps)

The core order in one sentence: **install the dsh source first, then run `apply.sh`** — `apply.sh` is a patching tool, not a dsh installer.

#### ① Prepare the environment

- Node.js **≥ 24** (verify with `node -v`)
- pnpm (verify with `pnpm -v`)
- git
- 🪟 Windows users: run the bash scripts in **Git Bash or WSL**; the dsh source itself is cross-platform

#### ② Get the dsh source

```bash
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install
```

> ⚠️ **Must be a `git clone` checkout** — the packaged `npm install` build won't work, because the patch modifies source files.
> ⚠️ **Do not use a shallow clone (`--depth 1`)** — the version pinning below needs the full history.
>
> The current master branch is the target version `0.1.1-rc.2` (commit `b150a55`). If upstream has moved on (`apply.sh` will warn about a version mismatch), pin the version first:
>
> ```bash
> git checkout b150a55
> pnpm install
> ```

#### ③ Clone deepseek-harness-lan and apply the patch

```bash
git clone https://github.com/oitsukiii/deepseek-harness-lan.git
cd deepseek-harness-lan
./apply.sh /path/to/deepseek-harness
```

`apply.sh` automatically: version check → verify the patch applies cleanly → apply → install the missing build dependency `unrun`. You're done when you see **`✓ 补丁应用完成`** (patch applied).

> 💡 **Directory-independent**: `deepseek-harness-lan` and `deepseek-harness` can live in any directories (any combination) — the script locates its own patch and the dsh checkout by argument, with no hardcoded paths. Three ways to run: pass the dsh path as an argument, `cd` into the dsh directory and run, or put deepseek-harness-lan next to dsh.

#### ④ Rebuild the frontend

```bash
cd /path/to/deepseek-harness
pnpm run build
```

> The randomUUID polyfill lives in the web bundle, **you must rebuild for it to take effect**.

#### ⑤ Start and bind a LAN IP

```bash
pnpm dsh web --host 192.168.1.100 --trusted-host 192.168.1.100
```

Replace `192.168.1.100` with your LAN IP (check `ip addr` or your router's admin page).

#### ⑥ Access and verify

On another device (Windows / phone / tablet), open in a browser:

```
http://192.168.1.100:3080
```

> ⚠️ If you opened it before, do a **Ctrl + F5 hard refresh** (the browser may cache the old JS).

**Verification checklist:**

- [ ] The page loads normally, title "DeepSeek Harness"
- [ ] Configuring a model API does not report 403 / `crypto.randomUUID is not a function`
- [ ] Other devices on the LAN can open it too

#### Revert (optional)

```bash
./revert.sh /path/to/deepseek-harness
```

Removes the patches with one command; afterwards you can `git pull` to update dsh normally.

---

## 🔀 Alternative: no source changes (SSH tunnel)

If you **don't want to modify the dsh source** (keeping it pristine for zero-maintenance official upgrades), an SSH tunnel is the only clean LAN access method — **zero patches, all three gates pass naturally**.

### Why it works without patching

dsh's trust check (browser-trust) **looks at the request's Host header, not the source IP** (DNS rebinding defense); and `crypto.randomUUID` is only available in a secure context (HTTPS or localhost). An SSH tunnel makes the browser always access dsh via `127.0.0.1`, so:

| Three gates | Under SSH tunnel | Why |
|---|---|---|
| Gate 1 (CLI/schema) | ✅ not triggered | dsh listens on `127.0.0.1` = official default, no changes needed |
| Gate 2 (browser-trust) | ✅ includes privileged endpoints | Host header = `127.0.0.1` → loopback exemption (the original privileged endpoints only allow loopback anyway) |
| Gate 3 (randomUUID) | ✅ available | `127.0.0.1` is a secure context; the browser provides it natively |

### Steps

```bash
# 1. Start dsh as official (no patch, listening on 127.0.0.1:3080)
cd /path/to/deepseek-harness
pnpm dsh web
```

On the computer you want to access from, open the tunnel (Windows 10/11 ships OpenSSH):

```powershell
ssh -N -L 3080:127.0.0.1:3080 <user>@<NAS-IP>
```

Open in the browser:

```
http://127.0.0.1:3080
```

API configuration, privileged endpoints, and all features work normally.

### Comparison

| Option | Source changes | Computer | Phone/tablet | Official upgrades |
|---|---|---|---|---|
| **SSH tunnel** (this option) | ❌ zero changes | ✅ | ⚠️ configure a tunnel per device | direct `git pull`, seamless |
| **deepseek-harness-lan patch** (main option) | ✅ 4 minimal diffs | ✅ | ✅ open the URL directly | need to re-apply the patch |

### Why nginx reverse proxy doesn't work

After a reverse proxy (HTTP or HTTPS), the Host header becomes the LAN IP, while the **original privileged endpoints** (`settings.describe`, `llm.providers`, etc. — required for configuring model APIs) use `isTrustedApiRequest(request, [])` which only allows loopback, so the configuration API step necessarily returns 403. The SSH tunnel is the only "no source changes + full functionality" path; if you want every device to open a URL directly, use the main patch option.

---

## 🧠 How it works

dsh officially blocks LAN access via **three gates**. The project's 4 patches break through them one by one:

### Gate 1: CLI rejects `0.0.0.0`, schema only accepts two literals

**Symptom**: `--host 0.0.0.0` fails immediately; binding a specific IP (e.g. `192.168.1.100`) also fails to start:

```
ValidationError: invalid config:
  - $.host expected "127.0.0.1" | "0.0.0.0" but got "192.168.1.100" (at host)
```

**Cause** (two layers of restrictions):

| Layer | Location | Restriction |
|---|---|---|
| CLI layer | `packages/bundle/web-app/src/startup.ts` | `options.host === '0.0.0.0'` triggers `program.error()` and refuses to start |
| Schema layer | `packages/host/webserver/src/index.ts` | zod validates `z.union([z.const('127.0.0.1'), z.const('0.0.0.0')])`, and the type definition only allows those two values |

**Patch**:

```diff
// packages/host/webserver/src/index.ts
- host: '127.0.0.1' | '0.0.0.0'      // type
+ host: string
- host: z.union([z.const('127.0.0.1'), z.const('0.0.0.0')]).required()   // zod
+ host: z.string().required()
```

```diff
// packages/bundle/web-app/src/startup.ts
- if (options.host === '0.0.0.0') {
-   program.error('...intentionally not supported yet for safety...')
- }
+ // only reject the 0.0.0.0 wildcard; specific LAN IPs are allowed
```

**Design trade-off**: the `0.0.0.0` wildcard binds to every interface (including public/WG), which is dangerous; binding a **specific IP** exposes only one interface and stays controllable. So only specific IPs are unlocked — the wildcard stays rejected.

### Gate 2: the /api browser-trust fence (403)

**Symptom**: the page opens, but every `/api/*` request returns `HTTP 403`, e.g.:

```
加载提供方目录失败: transport failure for /api/llm.providers: HTTP 403
```

**Cause**: there is a **browser-trust fence** in front of dsh's `/api` gateway (anti DNS-rebinding / cross-site attack) in `packages/client/connection/src/index.ts`:

```ts
// trust list: only when binding 0.0.0.0 does it collect all LAN IPs
// binding a specific IP → empty list → all non-localhost requests 403
const lanAddresses = bindHost === ALL_INTERFACES_HOST ? collectLanIps() : []
return { lanAddresses, trustedHosts: [...lanAddresses, ...extra] }
```

Additionally, **privileged methods** (`settings.*`, `credentials.*`, `agentPreset.*`, etc.) are checked against an **empty trust list** — meaning even with `--trusted-host`, those endpoints still only allow localhost:

```ts
if (PRIVILEGED_METHODS.has(method) && !isTrustedApiRequest(request, [])) {
  return new Response('forbidden', { status: 403 })
}
```

**Patch** (`packages/client/connection/src/index.ts`):

```diff
- && !isTrustedApiRequest(request, [])) {    // empty list: loopback only
+ && !isTrustedApiRequest(request, trustedHosts)) {   // explicit trust takes effect
```

**Design trade-off**: `--trusted-host` (the admin-configured explicit trust entry) now also applies to privileged endpoints. **Without `--trusted-host`, behavior is unchanged** — still loopback-only, so the official security semantics are preserved.

### Gate 3: `crypto.randomUUID is not a function`

**Symptom**: error when configuring APIs:

```
加载提供方目录失败: crypto.randomUUID is not a function
```

**Cause**: the browser Web Crypto API's `crypto.randomUUID()` is **only available in a secure context (HTTPS or localhost)**. When accessing `http://192.168.1.100:3080` (plaintext HTTP on the LAN), the function doesn't exist.

**Patch** (`apps/web/src/main.ts`, at the very top of the web entry):

```ts
// crypto.randomUUID is only available in secure contexts; add a UUIDv4
// implementation for plain-HTTP LAN environments
if (typeof globalThis.crypto === 'object' && typeof globalThis.crypto.randomUUID !== 'function') {
  try {
    globalThis.crypto.randomUUID = () =>
      'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0
        const v = c === 'x' ? r : (r & 0x3) | 0x8
        return v.toString(16)
      })
  } catch { /* keep as-is in read-only crypto environments */ }
}
```

> 💡 The UUID is only used for local identifiers (attachment drafts, session ids, etc.) and is not involved in security checks, so the polyfill has no security risk.

---

## 🔒 Security notes (please read)

- ⚠️ **This UI can execute arbitrary commands**. After patching, **any device on the LAN** can access and control your agent.
- ✅ Only use it on a **trusted home/office network**.
- ❌ **Do not** port-forward 3080 to the public internet (port forwarding / DMZ).
- ❌ **Do not** use `--host 0.0.0.0` (still rejected after patching — a deliberately kept line of defense).
- 💡 Advanced: put an **authenticating reverse proxy** (e.g. nginx Basic Auth) in front of dsh.
- 🔐 `--trusted-host` is the official browser-trust mechanism's explicit trust entry — only fill in your own LAN IP.

## 🧩 Compatibility

**This patch is written and verified against dsh `0.1.1-rc.2` (commit `b150a55`).**

> ⚠️ **Upstream note (0.1.1-rc.2)**: this dsh version has a known build issue of its own — `tsc`/`tsdown` cannot resolve the `@deepseek-ai/dsh-api-remotes` workspace package (missing `*/remote` subpath modules). Verified on a **clean upstream checkout with no patches applied**; it is not caused by this patch. The patch itself applies cleanly and all four patched files pass type-checking (`tsc -b tsconfig.client.json`); full-build verification is blocked until upstream fixes this. The previous target (0.1.0-rc.7) built cleanly.

- Verification chain: patch applies cleanly (`git apply --check`) → all four patched files pass `tsc` type-checking → Web UI page load → `/api` calls → privileged endpoints (`settings.describe`, etc.) all pass.
- dsh upstream iterates fast; **other versions will most likely break**:
  - When the source context changes, `apply.sh`'s `git apply --check` **fails and aborts safely** without dirtying your repo (this is a protection mechanism, not a bug).
- **Adapting to new versions**:
  1. Run `apply.sh` on the new version and note the conflicting files when it fails;
  2. Manually adapt by following the "three gates" approach in [🧠 How it works](#-how-it-works);
  3. PRs with adapted patches are welcome.
- **Revert**: `revert.sh` removes the patches in one command; afterwards you can `git pull` to update dsh normally.

## ❓ FAQ

**Q: Can I access it from my phone?**
A: Yes. As long as the phone is on the same LAN, open `http://<NAS-IP>:3080` in the browser.

**Q: What happens when dsh updates officially after patching?**
A: `apply.sh` runs `git apply --check` first; if the upstream code changed, it fails and aborts without dirtying your repo. Revert with `revert.sh`, then `git pull` normally.

**Q: Why not run it with Docker?**
A: dsh is officially distributed as a Node.js / npm package with no official Docker image; this project only modifies source, so following the official install path is the most stable.

**Q: Will the official project accept this patch?**
A: The official project **deliberately** blocks wildcard binding and is unlikely to relax it soon; but the "bind a specific IP + explicit trust" idea is worth an issue/discussion upstream.

## 🧩 Patch files

| File | Addresses |
|---|---|
| `patches/deepseek-harness-lan.patch` | unified diff of all 4 changes (use directly with `git apply`) |

## 🤝 Contributing

- Bugs / compatibility issues: open an issue with the dsh version + error message
- New platform / new version adaptation: open a PR, update the patch and verify on the target version
- Patch invalidated by upstream dsh updates: PRs with updated patches are welcome

## 🎉 Acknowledgements

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) — an excellent agent framework ("Everything is a Plugin")
- This project is developed with **DeepSeek V4 Flash** (troubleshooting → locating → patching → scripting → documentation, the whole flow)

## 📜 License

MIT License — an unofficial community project unrelated to DeepSeek Harness, for learning and personal reference only.
