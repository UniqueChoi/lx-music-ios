# iOS 版交付说明

> 目标：在你自己的 iPhone 上运行 LX Music（不上架 App Store）。
> 当前状态：**代码已就绪，等待一次 macOS 构建**。

---

## 一、现在能做什么

仓库里已经有一套完整的 iOS 适配代码，包含 8 个原生模块与全部平台分支。
在这台 Windows 机器上，它们已经通过了：

- **Objective-C 真实编译**（clang + 手写 SDK 桩头文件，7 个 `.m` 全部通过，0 error 0 warning）
- **算法级验证**（ASN.1 密钥转换与 OpenSSL 逐字节一致）
- **运行时契约验证**（用 Node 模拟宿主跑通自定义源脚本的完整请求链路）
- **接口一致性比对**（JS 调用 ↔ ObjC 导出，逐一对齐无缺失）

但**产不出 `.ipa`**——iOS 应用必须在 macOS + Xcode 上编译和签名。这是 Apple 的硬性限制。

---

## 二、出包路径：GitHub Actions（推荐，无需 Mac）

仓库里已经写好了 `.github/workflows/ios-build.yml`，推送即自动编译并产出未签名 ipa。
**你不需要买 Mac，也不需要装 Xcode。**

### 免费额度（真实数字，别被"2000 分钟"误导）

| 仓库类型 | 额度 | 折算成 macOS 时间 |
|---|---|---|
| **Public** | 无限免费 | 无限 |
| **Private** | 2000 分钟/月 | **约 200 分钟**（macOS 计费系数 10×） |

本项目的单次构建约 **25–40 分钟**（依赖 npm ci + pod install + xcodebuild）。
所以：

- 公开仓库：随便跑
- 私有仓库：**每月约 5–8 次构建**

> 选公开还是私有：代码基于 Apache-2.0，公开托管属正常使用（保留 LICENSE 与原作者署名即可）。
> 但如果你介意，用私有仓库 + 省着跑也够调通。

### 操作步骤

```bash
cd lx-music-mobile

# 1. 提交改动
git add -A
git commit -m "feat: iOS 适配（原生模块 + 平台分支 + CI 构建）"

# 2. 在 GitHub 建一个空仓库（不要勾选 README），然后
git remote remove origin
git remote add origin https://github.com/<你的用户名>/<仓库名>.git

# 3. 推到 master
#    注意：workflow 只在 master / dev 分支触发，
#    推到其他分支不会自动构建（推完也可以手动 Run workflow）
git push -u origin master
```

推送后：

3. 打开仓库 → **Actions** 标签页 → 左侧选 **iOS Build**
4. 想手动触发就点 **Run workflow**
5. 等 25–40 分钟

> `push` 带了 `paths` 过滤，只有改动 `ios/`、`src/`、`package*.json` 等才会构建；
> 同一分支有新推送会自动取消上一次（`cancel-in-progress`），不会白烧额度。

### 首次构建大概率失败

所有代码从未在真实 Apple SDK 下编译过。失败后：

1. 点开失败的 job
2. **不要**截图，直接把出错 step 的日志末尾 100 行左右复制给我
3. 我按报错修，你重跑

已经预置了三个会大幅减少来回次数的设计：

- **URL 重写**：`package-lock.json` 里 4 个依赖是 `git+ssh://git@github.com/`，CI 无 SSH key 会直接失败。workflow 用 `git config insteadOf` 全部改写成 https（已验证三种形态都能重写）
- **preload 一致性检查**：两份 `user-api-preload.js` 不一致时立刻报错，避免构建出一个行为异常的包
- **失败摘要**：失败时在 Actions 页面直接显示提示，不用翻日志找原因

### 拿到 ipa 之后

构建成功后，在 job 页面底部 **Artifacts** 下载 `LxMusicMobile-unsigned-ipa`（是个 zip，解压得 ipa）。

然后见下一节第 4 步。

---

## 三、（备选）有 Mac 时的本地构建

如果你之后能借到 Mac 或租云 Mac：

```bash
bash scripts/ios-build.sh
```

脚本与 CI 做同样的事，产物在 `ios/build/LxMusicMobile-unsigned.ipa`。

---

## 四、装到自己 iPhone（在 Windows 上完成）

1. Windows 上装 [Sideloadly](https://sideloadly.io)
2. 用你的 **Apple ID** 登录（免费账号即可）
3. 把 `LxMusicMobile-unsigned.ipa` 拖进去，连上 iPhone，点 Start
4. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书

**注意：免费 Apple ID 签名的 App 有效期 7 天**，到期后重新做这一步即可。
App 内的播放列表存在沙盒里，重签一般不会丢，但建议定期用 App 的「备份」导出到「文件」App。

---

## 五、这个 iOS 版包含什么

### 已实现（8 个原生模块）

| 模块 | 对应 Android | 说明 |
|---|---|---|
| `UtilsModule` | 同名 Java | 屏幕常亮、WiFi IP、通知授权、分享、locale、窗口尺寸 |
| `CryptoModule` | 同名 Java | AES / RSA / SHA1，含 4 个同步方法 |
| `CacheModule` | 同名 Java | 缓存统计与清理 |
| `UserApiModule` | QuickJS 版 | **用 JavaScriptCore 重写**，复用同一份 `user-api-preload.js` |
| `LocalMediaModule` | local-media-metadata | 用 AVFoundation 读本地音频元数据、封面、歌词 |
| `LXDER` | — | ASN.1 工具，SPKI/PKCS#8 ↔ PKCS#1 |

### 平台适配

- **后台音频**：`AppDelegate` 里配置 `AVAudioSession`，配合 `UIBackgroundModes: audio`，锁屏不断播
- **播放器**：iOS 分支不再传 `maxCacheSize` / `audioOffload` 等 ExoPlayer 专有参数
- **缓存 API**：`isCached` / `getCacheSize` / `clearCache` 在 iOS 上降级（RNTP 的 iOS 端没有这些方法）

### 已隐藏的 Android 独有功能

| 功能 | 原因 |
|---|---|
| 桌面歌词 | iOS 不允许第三方 App 创建全局悬浮窗，**技术上无法实现** |
| 蓝牙歌词 | 依赖 Android 的蓝牙广播机制 |
| 音频焦点开关 | iOS 由 AVAudioSession 自动处理 |
| 音频卸载开关 | ExoPlayer 的省电特性 |
| 播放缓存大小 | iOS 由系统 NSURLCache 管理 |
| 「显示退出按钮」 | iOS 不允许 App 主动退出 |

---

## 六、已知限制

| 项目 | 状态 |
|---|---|
| 本地音乐写回标签 | iOS 不支持（`writeMetadata` / `writePic` 会明确报错，不会静默失败） |
| 封面导出 | 支持读取，导出为 jpg 到缓存目录 |
| 歌词 | 优先读同名 `.lrc`，其次读内嵌歌词；写歌词会生成 `.lrc` 文件 |
| 应用内更新 | iOS 无此机制，更新需重新签名安装 |

---

## 七、如果构建失败

**大概率会失败，这是正常的**——所有代码从未在真实 Apple SDK 下编译过。
把 Xcode 的报错发给我，我按报错修。

最可能出问题的位置（按概率排序）：

1. **`pod install` 阶段** — `react-native-navigation 7.39.2` × `RN 0.73` × `SwiftAudioEx 0.14.7` 的组合未实测
2. **`RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD`** — 需确认未开启新架构（`newArchEnabled=false` 已设置）
3. **`SecKeyCreateWithData` 签名差异** — 我的 SDK 桩可能比真实 API 宽松
4. **`resource_bundles` 资源路径** — `NSBundle` 查找写了三级回退，但没实测

---

## 八、质量保证说明

这套代码**没有**经过真机验证，但做了这些能做的检查：

| 检查 | 手段 | 结果 |
|---|---|---|
| ObjC 语法与类型 | clang 真实编译（7 个文件） | ✅ 0 error / 0 warning |
| DER 编码正确性 | 与 OpenSSL 逐字节比对（RSA-1024~4096） | ✅ 完全一致 |
| 自定义源运行时 | Node 模拟宿主跑通完整请求链路 | ✅ PASS |
| JS↔ObjC 接口 | 静态比对调用与导出 | ✅ 零缺失 |
| JS 平台分支 | 检查编译产物字节码 | ✅ 确认生效 |
| 打包可行性 | `react-native bundle --platform ios` | ✅ 成功 |

**能查的错都查了，查不了的是只有 macOS 才能暴露的那些。**
