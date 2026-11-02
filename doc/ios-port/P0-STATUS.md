# P0 进度：iOS 工程构建打通

> 阶段目标：让 iOS 工程具备可编译的骨架，并在云端 macOS 上通过 `xcodebuild`。
> 完成判据（Definition of Done）：GitHub Actions 的 `iOS Build` 工作流绿色通过，且能产出未签名 `.ipa`。

## 关键前提

本机为 Windows，**无法执行 `pod install` / `xcodebuild` / 模拟器**。
因此 P0 的"已验证"一律指 **CI 上的构建结果**，本地只能做静态校验。

---

## 已完成

| # | 事项 | 文件 | 说明 |
|---|---|---|---|
| 1 | 关闭 Flipper | `ios/Podfile` | 避免与 react-native-navigation 7.x 构型冲突；同时把所有 pod 的 `IPHONEOS_DEPLOYMENT_TARGET` 抬到 13.4 |
| 2 | 后台音频能力 | `ios/LxMusicMobile/Info.plist` | 补 `UIBackgroundModes: audio`（缺此项锁屏即断播） |
| 3 | 文件共享 | `ios/LxMusicMobile/Info.plist` | `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`，用于导入本地音乐与备份 |
| 4 | 网络策略 | `ios/LxMusicMobile/Info.plist` | 自用构建放开 ATS（源脚本可能走 http）；上架须回调 |
| 5 | 设备能力 | `ios/LxMusicMobile/Info.plist` | `armv7` → `arm64`；显示名 `LX Music` |
| 6 | Bundle ID | `project.pbxproj` | `org.reactjs.native.example.*` → `com.local.lxmusic`（测试 target 为 `.Tests`） |
| 7 | 版本号 | `project.pbxproj` | `MARKETING_VERSION=1.9.1`、`CURRENT_PROJECT_VERSION=78`，与 `package.json` 对齐 |
| 8 | 应用图标 | `Images.xcassets/AppIcon.appiconset/` | 由 `doc/images/icon.png` 生成 9 个尺寸（**占位，源图仅 200×200，建议后续换 1024 源图**） |
| 9 | 自动链接裁剪 | `react-native.config.js` | 关闭两个无 iOS 源码 fork 的 iOS 自动链接（见下） |
| 10 | 文件系统桩 | `src/utils/fs.ios.ts` | react-native-fs + pako 复刻全部同名 API |
| 11 | 元数据桩 | `src/utils/localMediaMetadata.ios.ts` | 读操作安全降级为 `null`，写操作显式报错 |
| 12 | 系统能力桩 | `src/utils/nativeModules/utils.ios.ts` | 用 RN 内置 API 替代 UtilsModule |
| 13 | 源脚本运行时桩 | `src/utils/nativeModules/userApi.ios.ts` | 监听空操作，加载脚本报明确错误 |
| 14 | CI 构建流水线 | `.github/workflows/ios-build.yml` | macOS runner 编译 + 打未签名 ipa |

---

## 已验证（本机可验证部分）

| 项 | 方法 | 结果 |
|---|---|---|
| `Info.plist` 合法性 | `plistlib` 解析 | ✅ 20 个键，`UIBackgroundModes=['audio']` |
| AppIcon 资源清单 | JSON 解析 | ✅ 9 个条目，文件齐备（40/60/58/87/80/120/120/180/1024 px） |
| 新增文件 lint | `eslint` | ✅ 0 problem |
| 新增文件类型检查 | `tsc --noEmit` | ✅ 我改的文件 0 error |
| **iOS JS bundle 可打包** | `react-native bundle --platform ios` | ✅ 成功，2.56 MB，8 个资源 |
| **iOS 确实选中平台文件** | 检查产物中的特征串 | ✅ 4 个 `.ios.ts` 全部进入 bundle |
| **Android 未被污染** | `react-native bundle --platform android` | ✅ 仍使用原生 SAF，未混入 iOS 桩 |

### 关于第 4 项的实验（重要）

担心点：`@/` 别名由 `babel-plugin-module-resolver` 解析，若它在 babel 阶段就把 `.ios.ts` 写死进 import，Android 构建会拿到 iOS 实现。

实测（`D:\dsh\ios-audit\resolver-test`，使用仓库原样的 extensions 列表）：

```
A) fs.ts + fs.ios.ts + fs.android.ts  →  import { impl } from "./utils/fs";
B) fs.ts + fs.ios.ts                  →  import { impl } from "./utils/fs";
C) 仅 fs.ios.ts                       →  import { impl } from "./utils/fs";
```

三种组合下都**保留无扩展名**，说明插件只重写别名前缀，实际扩展名由 Metro 按平台决定。
结论：新增 `.ios.ts` 对 Android 零影响，可以放心使用平台文件。

### 关于 bundle 验证（这是本机能做到的最强证据）

`react-native bundle --platform ios` 会真实跑一遍 Metro 的平台解析与依赖图构建，
等价于验证「iOS 端 JS 能否加载」。产物特征串核对结果：

| 检查项 | 期望 | 实测 |
|---|---|---|
| `fs.ios.ts` 的 `在 iOS 上不可用` | 存在 | ✅ 存在（被转义为 `\u5728…`） |
| `userApi.ios.ts` 的 P2 占位提示 | 存在 | ✅ 存在 |
| `localMediaMetadata.ios.ts` 的 P3 占位提示 | 存在 | ✅ 存在 |
| `utils.ios.ts` 的 `不支持安装 APK` | 存在 | ✅ 存在 |
| `openDocumentTree` / `getPersistedUriPermissions` / `SDCardDir` | 不存在 | ✅ 均未出现 |

Android bundle 反向核对：仍包含 SAF 相关 API，未包含任何 iOS 桩字符串。
（Android 产物中出现的 `CachesDirectoryPath` 来自 `react-native-fs` 模块自身，属正常。）


---

## 未验证（必须等 CI）

- `pod install` 能否跑通（RNN 7.39.2 × RN 0.73 × SwiftAudioEx 0.14.7 的组合未实测）
- Xcode 编译是否通过
- 运行期是否还会因其他原生模块缺失而崩溃
- 未签名 ipa 能否被 Sideloadly 正常重签安装

---

## 已知缺口（P1 及以后）

| 缺口 | 影响 | 计划 |
|---|---|---|
| `UtilsModule` 的屏幕常亮（idleTimer） | 播放页不会阻止息屏 | P1 原生实现 |
| `getWIFIIPV4Address` 返回 `127.0.0.1` | 同步页显示的本机地址不可用 | P1 用 `getifaddrs` |
| 通知权限查询恒为 `true` | 权限提示逻辑不生效 | P1 `UNUserNotificationCenter` |
| `CryptoModule` 无 iOS 实现 | 未导入自定义源时无影响；一旦走平台 SDK 签名就会崩 | P1 |
| 自定义源脚本无法运行 | 在线播放全部不可用 | P2（JavaScriptCore） |
| 本地音乐元数据读取为 `null` | 导入的本地歌曲无标题/专辑信息 | P3 |
| 缓存统计/清理 | 播放缓存面板无数据 | P4 |
| 桌面歌词 | 已按决定砍掉，设置项需在 P5 隐藏 | P5 |

---

## 下一步

1. 把仓库推到你的 GitHub（私有仓库亦可），确认 Actions 可跑 macOS runner。
2. 手动触发 `iOS Build`，把它跑到绿色 —— 这是 P0 的验收动作。
3. 若 `pod install` 或编译失败，把失败日志给我，按报错修（大概率集中在 RNN 与 SwiftAudioEx）。
4. 通过后进入 P1：实现 `CryptoModule` / `UtilsModule` / `CacheModule` 三个 iOS 原生模块。
