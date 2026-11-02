# LX Music 移动版 iOS 移植：可行性与工程量审计

| 项 | 值 |
|---|---|
| 代码基线 | `fb84807` / v1.9.1（2026-09-19，`master`，浅克隆） |
| 代码规模 | 751 个受控文件；`src/` 594 个 ts/tsx/js，57,321 行；Java 约 3,288 行 |
| 审计日期 | 2026-10-29 |
| 目标 | 自用 iPhone 安装运行（**不上架 App Store**） |
| 审计方式 | 全量静态分析 + 上游 fork 仓库按 pin 的 commit 逐目录核对 |
| 审计未做 | **任何编译验证**（当前环境为 Windows，无 Xcode / CocoaPods） |

---

## 0. 结论先行

1. **技术可行，且比预期乐观。** 最难的部分（自定义源脚本运行时）在 Android 侧的原生契约只有 **7 个全局函数 + 一个 22 KB 预载 JS**，iOS 可用系统自带 JavaScriptCore 完整复用，不需要引入第三方 JS 引擎。
2. **有两处必须替换的依赖**（`react-native-file-system`、`react-native-local-media-metadata` 的 fork 版本**根本没有 iOS 源码**），否则编译能过、运行时必然崩。
3. **一个功能必须放弃**：桌面歌词（iOS 不允许第三方全局悬浮窗）。这不是适配问题，是平台能力缺失。
4. **工程量**：能跑通核心播放（M1）约 **25–35 人日**；除桌面歌词外接近功能对齐约 **50–70 人日**。不含真机反复调试的等待时间。
5. **"打包发布"必须拆段**：产物只能在 macOS 上生成。不走 App Store 的可行路径是「云端 macOS 构建未签名 ipa → Windows 端自签安装」，或「借一台 Mac 用 Xcode 免费个人团队直装」。免费 Apple ID 签名的 App **7 天过期**、最多 3 个。
6. **本机（Windows）无法产出 `.ipa`**，这是物理限制，不是配置问题。

---

## 1. iOS 工程现状：底子比想象中好

`ios/` 不是纯 RN 模板，`AppDelegate.mm` 已经接好了 React Native Navigation 的启动：

```objc
RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
[ReactNativeNavigation bootstrapWithBridge:bridge];
```

| 文件 | 现状 | 需要做的事 |
|---|---|---|
| `ios/LxMusicMobile/AppDelegate.mm` | 已 bootstrap RNN，bundle 走 `main.jsbundle` | 加 `UIApplication` 后台音频会话处理、RNN 生命周期回调 |
| `ios/Podfile` | RN 0.73 标准模板，Flipper 默认开 | 关 Flipper（与部分 pod 冲突）、确认 RNN / RNTP 的 iOS 部署目标 |
| `ios/LxMusicMobile/Info.plist` | **缺 `UIBackgroundModes`** | 加 `audio`，否则锁屏/切后台立即断播 |
| `project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER = org.reactjs.native.example.$(PRODUCT_NAME)` | 换成你自己的唯一 bundle id（自签必需） |
| `Images.xcassets/AppIcon.appiconset` | 空占位，只有 `Contents.json` | 提供 1024×1024 及各尺寸图标 |
| `Info.plist` ATS | `NSAllowsArbitraryLoads=false` | 源脚本可能请求 http 接口 → 需按域名开例外或允许任意加载（自用可放宽） |
| `UIRequiredDeviceCapabilities` | `armv7` | 该值已过时，建议改为 `arm64` |

> 也就是说：**iOS 骨架已有 30%，缺的是原生模块、配置和全部适配。**

---

## 2. 依赖可用性核查（硬证据）

对 `package.json` 里 4 个 `github:` fork，按其 pin 的 commit 直接拉取仓库根目录与 podspec 核对：

| 依赖 | pin | iOS 源码 | 结论 |
|---|---|---|---|
| `react-native-background-timer` | `55ecaa8` | ✅ `ios/RNBackgroundTimer.{h,m}` | **可用**，无需改动 |
| `react-native-track-player` | `bfe3393` | ⚠️ 有 `ios/RNTrackPlayer`，但缺少 fork 新增的缓存 API | **可用但需兼容层**，见下 |
| `react-native-file-system` | `fcb0e6f` | ❌ 根目录只有 `.yarn / android / example / src`，**没有 `ios/`** | **必须替换** |
| `react-native-local-media-metadata` | `1b5be31` | ❌ 同上，**没有 `ios/`** | **必须替换** |

### 2.1 两个"假 podspec"

这两个 fork 的 podspec 都写着：

```ruby
s.source_files = "ios/**/*.{h,m,mm}"
```

但仓库里并没有 `ios/` 目录。后果很隐蔽：**`pod install` 不会报错**（空 glob 合法），编译也过，直到运行期访问 `NativeModules.FileSystemModule` / `readMetadata` 才抛 undefined —— 属于典型的"编译通过、启动即崩"。

### 2.2 track-player：iOS 缺 3 个缓存 API

对 `ios/RNTrackPlayer/` 全部源码 grep `isCached|getCacheSize|clearCache|audioOffload|maxCacheSize|waitForBuffer`，**0 命中**。而 JS 侧在用：

```ts
// src/plugins/player/utils.ts:184-186
export const isCached = async(url: string) => TrackPlayer.isCached(url)
export const getCacheSize = async() => TrackPlayer.getCacheSize()
export const clearCache = async() => TrackPlayer.clearCache()
```

以及 `src/plugins/player/index.ts:30-37` 的 `setupPlayer({ maxCacheSize, maxBuffer, waitForBuffer, audioOffload, handleAudioFocus })` 全是 ExoPlayer 概念。

**处理方案**：写一层平台兼容模块（`src/plugins/player/utils.ios.ts` 或 `Platform.select` 分支），iOS 上缓存统计返回 0、清缓存退化为清 `NSURLCache`、`isCached` 恒 `false`。这不影响播放，只影响"缓存大小显示/清理"这类次要功能。

---

## 3. 原生模块移植清单

Android 侧共 5 个自研原生模块，3,288 行 Java：

| 模块 | Java 行数 | iOS 方案 | 难度 | 估时 |
|---|---|---|---|---|
| `userApi/`（自定义源运行时） | 483 | **JavaScriptCore**（系统框架）+ 复用 22 KB 预载脚本 | 中 | 5–7 d |
| `lyric/`（桌面歌词悬浮窗） | 1,693 | **不可移植** | — | 不做 |
| `crypto/`（AES/RSA/MD5/SHA1） | 337 | CommonCrypto + Security.framework（RSA 用 `SecKey`） | 中 | 2–3 d |
| `cache/` | 173 | `NSURLCache` + 沙盒目录统计 | 低 | 1 d |
| `utils/`（设备/权限/分享/网络地址） | 602 | ObjC/Swift 重写；部分用 RN 内置 API 替代 | 低 | 2–3 d |

### 3.1 关键的"好消息"：源脚本运行时契约极小

`QuickJS.java` 向脚本环境注入的原生能力，全部加起来只有 7 个：

```
__lx_native_call__(key, action, data)      // 脚本 → App 的消息通道
__lx_native_call__utils_str2b64(str)       // Base64 编码
__lx_native_call__utils_b642buf(b64)       // Base64 解码为字节数组
__lx_native_call__utils_str2md5(str)       // MD5
__lx_native_call__utils_aes_encrypt(...)   // AES
__lx_native_call__utils_rsa_encrypt(...)   // RSA
__lx_native_call__set_timeout(fn, ms)      // 定时器
```

真正的 `lx.*` API 全部实现在 **`android/app/src/main/assets/script/user-api-preload.js`（21,935 字节）**，是一段纯 JS，与平台无关。

因此 iOS 侧工作量 = 「一个 JSC 上下文 + 7 个 block + 一条独立线程 + 事件回传」，而不是重写整个源脚本协议。预载脚本可**原样复用**，脚本生态兼容性风险大幅降低。

JS 侧对接面同样集中在两处：
- `src/utils/nativeModules/userApi.ts`（100 行，桥接声明）
- `src/core/init/userApi/{index.ts, request.js}`（251 + 115 行，init/request/response/log 状态机）

### 3.2 必须重写的两个"收口点"（工作量可控）

| 文件 | 行数 | 说明 |
|---|---|---|
| `src/utils/fs.ts` | 89 | **全 App 唯一文件系统入口**，被 20+ 处调用。iOS 版改为 RNFS + 沙盒路径 + UIDocumentPicker |
| `src/utils/localMediaMetadata.ts` | 57 | 本地音乐元数据读取。iOS 需换 `AVAsset`/ID3 解析，或改为"只支持导入不带元数据的文件" |

`fs.ts` 里 Android 专属的 API 有明确清单，iOS 侧可直接置空或换实现：

```ts
export const externalStorageDirectoryPath = Dirs.SDCardDir          // iOS 无 SD 卡
export const getExternalStoragePaths = async(...)                    // 同上
export const selectManagedFolder = async(...) => AndroidScoped.openDocumentTree(...)
export const selectFile = async(...) => AndroidScoped.openDocument(...)
export const removeManagedFolder = async(...) => AndroidScoped.releasePersistableUriPermission(...)
export const getPersistedUriList = async(...) => AndroidScoped.getPersistedUriPermissions()
export const gzipFile / gzipString ...                               // 可保留（自己在 ObjC 实现 zlib）
```

### 3.3 UI 层几乎平台中立

全仓库对平台的判断只有**一处**：

```ts
// src/utils/tools.ts:27
export const isAndroid = Platform.OS === 'android'
```

且只用于 `isSupportedAutoTheme`。222 个 screen 文件、71 个 component 文件里没有第二处 `Platform.OS` 分支。这意味着 **UI 不需要重写，只需适配**（安全区、状态栏高度、手势返回、`Modal` 呈现方式、自绘 Toast）。

---

## 4. 功能可用性矩阵

| 功能 | iOS | 说明 / 替代方案 |
|---|---|---|
| 在线搜索、榜单、歌单 | ✅ | 纯 JS，依赖 `fetch` |
| 自定义源脚本 | ✅ | JSC 重写宿主，预载脚本复用 |
| 播放 / 后台播放 / 锁屏控制 | ✅ | RNTP + `UIBackgroundModes: audio` + `MPNowPlayingInfoCenter` |
| 歌词显示、翻译、罗马音 | ✅ | 纯 JS |
| 我的列表 / 收藏 / 播放记录 | ✅ | AsyncStorage（分片存储逻辑与平台无关） |
| 数据同步（自建服务端） | ✅ | 需补 iOS 的 `getWIFIIPV4Address`（`getifaddrs`） |
| 本地音乐扫描 | ⚠️ | iOS 无整盘扫描。改为「Files/分享 → 导入到沙盒」 |
| 下载歌曲到本地 | ⚠️ | 只能存沙盒 Documents，无法写公共目录；`UIDocumentPicker` 导出 |
| 缓存大小统计与清理 | ⚠️ | RNTP fork 无 iOS 缓存 API，降级为 `NSURLCache` 统计 |
| **桌面歌词（悬浮窗）** | ❌ | iOS 不允许第三方 App 创建全局悬浮窗。**功能删除** |
| 蓝牙歌词 | ❌ | Android 广播机制；iOS 无对应能力，删除 |
| 应用内更新（下载 APK 安装） | ❌ | iOS 无此机制；改为「提示去项目主页」 |
| 通知栏封面图 | ✅ | RNTP 的 `artwork` |
| 分享歌曲 | ✅ | 改用 RN `Share.share`（Android 版走原生 `shareText`） |
| 主题 / 字体大小 / 多语言 | ✅ | 纯 JS |

---

## 5. 分阶段实施计划

> 估时单位为「人日」，按熟悉 RN 的开发者计。阶段之间有依赖，建议顺序推进。

### P0 · 构建打通（1–2 d）
- 关 Flipper、修 pod 版本冲突、确认 RNN 7.39.2 与 RN 0.73 的 iOS 兼容
- 换 bundle id、补 `UIBackgroundModes: audio`、补 AppIcon
- **验收**：空壳 App 能在模拟器/真机启动，RNN 首页能渲染

### P1 · 原生基础模块（6–9 d）
- 新建 `ios/LxMusicMobile/Modules/`：`UtilsModule`、`CryptoModule`、`CacheModule`
- `CryptoModule` 暴露 `RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD`（`aesEncryptSync` 等是同步调用）
- 对应 JS 侧加 `.ios.ts` 分支：`src/utils/nativeModules/{utils,crypto,cache}.ts`
- **验收**：`cryptoTest.ts` 全绿；缓存统计/清理可用；屏幕常亮、分享、退出 App 可用

### P2 · 自定义源运行时（5–7 d）
- `ios/.../UserApi/`：`JSContext` + 7 个 block + 独立 `NSThread` + `RCTEventEmitter`
- 把 `user-api-preload.js` 加入 Xcode 资源（或复用一个共享目录，避免两份拷贝）
- 对齐 `loadScript / sendAction / onScriptAction / destroy` 四个接口
- **验收**：导入一个源脚本 → 初始化成功 → 能返回播放链接

### P3 · 文件系统与本地音乐（6–8 d）
- 重写 `src/utils/fs.ts` 的 iOS 版（RNFS + 沙盒路径）
- 替换 `local-media-metadata`：`AVAsset` 取时长/元数据，或先做「无元数据导入」
- 备份导入导出改用 `UIDocumentPickerViewController`
- **验收**：播放列表导入/导出、本地文件导入播放、歌词/封面读取可用

### P4 · 播放与后台音频（4–6 d）
- RNTP iOS 缓存 API 兼容层（见 2.2）
- `AVAudioSession` 类别/中断处理、锁屏与耳机键、`MPNowPlayingInfoCenter`
- **验收**：锁屏可控、切后台不断播、来电打断后能恢复

### P5 · UI 适配（4–6 d）
- 安全区（刘海/灵动岛）、状态栏高度、`isAlwaysKeepStatusbarHeight`
- 手势返回、`Modal` → `presentation: 'overFullScreen'`、自绘 Toast 在 iOS 的层级
- 设置项按平台隐藏：桌面歌词、蓝牙歌词、应用内更新、电池优化白名单
- **验收**：所有页面无遮挡/无错位，Android 独有设置项不再出现

### P6 · 真机签名安装（1–2 d，依赖你的账号）
- 按第 6 节选定的路径出包并安装
- **验收**：iPhone 上双击图标启动，播放正常

**合计**：M1（P0–P2，能播放）≈ **12–18 人日**；完整对齐（P0–P6）≈ **27–40 人日**。若包含本地音乐与大量真机调试，向上浮动到 50–70 人日。

---

## 6. "不上架"的发布路径

### 方案 A（推荐，零 Mac）：云端构建 + 本地自签
1. GitHub Actions 用 `macos-14` runner：`pod install` → `xcodebuild archive` → 打未签名 `.ipa`
2. 在 Windows 上用 **Sideloadly / AltStore** 拿你的 Apple ID 重签并安装
3. 优点：不需要 Mac；缺点：免费账号 **7 天过期**，需定期重签

### 方案 B：借一台 Mac
- Xcode 打开 `ios/LxMusicMobile.xcworkspace`，选免费个人团队签名，直接 Run 到手机
- 同样受 7 天限制；用付费账号则 1 年

| | 免费 Apple ID | 付费开发者账号（$99/年） |
|---|---|---|
| 签名有效期 | **7 天** | 1 年 |
| 可装 App 数 | 3 个 | 100 台设备 |
| 推送 / iCloud / App Groups | ❌ | ✅（本 App 用不到） |
| 后台音频 | ✅ | ✅ |

**你需要提供**：Apple ID 类型；一个唯一 bundle id（例如 `com.yourname.lxmusic`）。

> 说明：免费签名到期后 App 会打不开，重签即可，**沙盒内的播放列表数据通常保留**，但建议定期用 App 内"备份"功能导出。

---

## 7. 风险清单

| 风险 | 影响 | 缓解 |
|---|---|---|
| RNN 7.39.2 × RN 0.73 的 iOS 兼容性未实测 | P0 可能受阻 | 先用最小工程验证，再动业务代码 |
| `SwiftAudioEx 0.14.7` 在新 Xcode 下编译失败 | P4 受阻 | 允许升级该 pod 或改用 RNTP 上游 iOS 实现 |
| 源脚本依赖 Android 特有行为（如 `lx.env` 字段） | 部分脚本不可用 | 预载脚本复用已覆盖大部分；按脚本实测 |
| 免费签名 7 天过期 | 使用中断 | 付费账号或定期重签 |
| 无法在本机验证任何 iOS 构建 | 返工风险 | 每阶段以「能在 CI 上 `xcodebuild` 通过」为强制门槛 |

---

## 8. 明确的能力边界

以下事情在当前环境（Windows / 无 Apple 凭据）下**做不了**，不要计划成"交付即用"：

- 产出可安装的 `.ipa`
- 执行 `pod install`、`xcodebuild`、iOS 模拟器验证
- 用你的 Apple ID 签名
- 承诺"打包发布完成"——发布必然需要你的账号与一台 macOS（自有或 CI）

---

## 9. 下一步需要你确认

1. **是否按 P0 → P1 先做？** 建议先用最小工程验证「RNN + RNTP pod 能否编译」，这是最大不确定性。
2. **Apple ID 有没有付费开发者账号？** 决定是 7 天重签还是 1 年一劳永逸。
3. **桌面歌词确认放弃？** 若必须保留，唯一替代是 iOS 16+ 的 Live Activity（锁屏/灵动岛），体验与悬浮窗差很多，且需另写 Widget Extension。
