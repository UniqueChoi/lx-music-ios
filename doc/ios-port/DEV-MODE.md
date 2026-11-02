# 快速迭代：免重装调试

> 解决什么问题：之前每次改代码都要「构建 10 分钟 → 下载 ipa → Sideloadly 重签 → 重装」。
> 装一次**调试版**之后，改 JS 只需在手机上刷新，几秒钟生效。

---

## 先说清楚两件事

**1. Windows 上没有 iOS 模拟器，也没有第三方插件能替代。**

iOS 模拟器本质是 macOS 上的一个进程，依赖 Apple 的 Metal
和私有框架，只能在 macOS + Xcode 里运行。Windows 上的
「iOS 模拟器」类工具都是安卓模拟器换了图标。

**2. 真正省时的是「调试版 + Metro 热更新」，不是模拟器。**

这也正好绕开模拟器：直接在真机上开发，效果比模拟器更真实。

---

## 一次性准备（约 15 分钟）

### 第 1 步：装调试版

在 GitHub Actions 页面手动触发构建：

1. 打开 https://github.com/UniqueChoi/lx-music-ios/actions
2. 左侧选 **iOS Build** → 右侧 **Run workflow**
3. `build_type` 选 **debug**
4. 等 10 分钟，下载产物 `LxMusicMobile-debug.ipa`
5. Sideloadly 重签安装（和之前一样）

> 调试版和正式版的区别：调试版**不含 JS 代码**，启动时去电脑上取，
> 所以能热更新。正式版把 JS 打进包里，可以脱离电脑独立运行。

### 第 2 步：让电脑和手机连同一个 Wi-Fi

手机和电脑必须在**同一局域网**，且电脑防火墙放行 8081 端口。

查电脑 IP：

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254\.' } |
  Select-Object IPAddress, InterfaceAlias
```

记下形如 `192.168.x.x` 的那个。

### 第 3 步：电脑上启动 Metro

```powershell
cd D:\dsh\lx-music-mobile
npx react-native start
```

窗口保持开着。看到 `Metro waiting on exp://...` 或
`Dev server ready` 即可。

### 第 4 步：告诉 App 去哪找 Metro

打开手机上的 LX Music：

1. **摇一摇手机** → 弹出 Dev Menu
   （或点屏幕任意处三指同时按下）
2. 选 **Settings**（有的版本叫 **Dev Settings**）
3. 找到 **Debug server host & port for device**
4. 填入：`192.168.x.x:8081`（换成第 2 步的 IP）
5. 返回，**Reload**

如果连上了，App 会正常启动。第一次可能需要点
「允许访问本地网络」的系统弹窗。

---

## 日常开发流程（几秒一次）

```
改 JS  →  手机摇一摇 → Reload
```

或者开 **Fast Refresh**：保存文件后自动刷新，连摇一摇都不用
（Dev Menu 里可以开关）。

**不需要重新构建，不需要重装。**

---

## 什么时候仍然需要重新构建

| 改动类型 | 是否要重建 |
|---|---|
| `src/**` 下的 JS / TS / TSX | ❌ 不用，热更新 |
| `ios/LxModules/**` 原生代码 | ✅ 要重建 |
| `Info.plist`、`Podfile`、`AppDelegate` | ✅ 要重建 |
| `package.json` 加新依赖 | ✅ 要重建且需 `pod install` |

也就是说：**UI 布局、逻辑、文案这类改动占绝大多数，都可以热更新。**
原生模块已经写完了，短期内不会频繁动。

---

## 常见问题

**连不上 / 一直白屏**

1. 确认手机和电脑同一 Wi-Fi（别一个连 5G 一个连 2.4G 的不同网段）
2. 电脑防火墙放行 Node.js：
   ```powershell
   New-NetFirewallRule -DisplayName "Metro 8081" -Direction Inbound -LocalPort 8081 -Protocol TCP -Action Allow
   ```
3. 在手机浏览器访问 `http://192.168.x.x:8081`，能看到 Metro 的提示页说明网络通

**改了代码没生效**

Metro 有缓存，重启时加 `--reset-cache`：

```powershell
npx react-native start --reset-cache
```

**红屏报错**

红屏里会直接显示文件和行号。把红屏内容发我即可，
比截图崩溃弹窗有用得多。

**想回到正式版**

重新构建 `build_type=release` 的包，装回去就行。
调试版依赖电脑，不适合日常使用。

---

## 为什么不用 CodePush / Expo Updates

- **CodePush** 已停止服务（微软 2024 年关闭 App Center）
- **Expo Updates** 需要改造整个项目接入 Expo 体系，成本远高于收益
- 自建热更新服务需要服务端 + 证书管理，对这个自用项目是过度设计

调试版 + Metro 是成本最低、最贴近官方的方案。
