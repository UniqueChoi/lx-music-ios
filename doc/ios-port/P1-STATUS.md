# P1 进度：三个 iOS 原生模块

> 目标：补齐 Android 侧 `UtilsModule` / `CryptoModule` / `CacheModule` 的 iOS 实现，
> 使 `src/` 下的共享 JS 代码无需平台分支即可运行。

## 交付内容

以**本地 CocoaPod** 形式引入（不改 `project.pbxproj`，避免手工编辑工程文件损坏）：

```
ios/LxModules/
  LxModules.podspec
  ios/
    LXDER.h / LXDER.m              最小 ASN.1 DER 工具（密钥格式互转）
    LxCryptoModule.h / .m          → CryptoModule
    LxUtilsModule.h / .m           → UtilsModule
    LxCacheModule.h / .m           → CacheModule
```

`ios/Podfile` 增加一行：

```ruby
pod 'LxModules', :path => './LxModules'
```

同时删除了 `src/utils/nativeModules/utils.ios.ts`——原生模块现在暴露**与 Android 完全一致**的接口，
共享的 `src/utils/nativeModules/utils.ts` 可直接复用，不再需要平台分支（减少日后两份代码漂移）。

## 接口对齐方式

不是"照着感觉写"，而是逐条对照 Android 的 Java 实现确定语义：

| 能力 | 对齐要点 |
|---|---|
| AES | 入参 data/key/iv 均为 base64；iv 为空串走 ECB（Java `"AES"` = `AES/ECB/PKCS5Padding`）；iv 不足 16 字节补零、超出截断（复刻 `AES.java` 的 `finalIvs`） |
| RSA | 公钥 X.509 SPKI、私钥 PKCS#8，均为去掉 PEM 头尾的 base64；明文也是 base64；异常一律返回 `""`（Java 就是这样吞异常的） |
| SHA1 | 小写十六进制 |
| CryptoModule 同步方法 | `rsaEncryptSync` 等 4 个用 `RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD`；**仅在旧架构可用**，而本项目 `newArchEnabled=false`（Android 侧同名开关），iOS 未设 `RCT_NEW_ARCH_ENABLED`，故成立 |
| getSystemLocales | 输出 `language_country` 全小写（如 `zh_cn`），与 Java 格式化结果一致，供 `src/lang` 匹配语言包 |
| 窗口尺寸 | Android 取 `getWindowVisibleDisplayFrame`，iOS 取 key window bounds |

### 平台能力缺失（不是没做完）

| 方法 | iOS 行为 | 原因 |
|---|---|---|
| `exitApp` | 空实现 | Apple HIG 明确反对 App 主动退出 |
| `installApk` | reject | 无 APK 概念 |
| `isIgnoringBatteryOptimization` / `requestIgnoreBatteryOptimization` | 恒定 `YES` | iOS 无电池优化白名单 |
| `getSupportedAbis` | `["arm64"]` | iOS 设备只有 arm64 |

## 已验证

| 项 | 方法 | 结果 |
|---|---|---|
| JS ↔ ObjC 接口一致性 | 脚本提取 `RCT_EXPORT_*` 方法名，与 `src/` 中所有 `XxxModule.method` 调用求差集 | ✅ Crypto 10/10、Utils 15/15、Cache 2/2，**无缺失、无多余** |
| ASN.1 转换正确性 | 独立复刻算法 + **另写的** DER 解析器交叉验证 | ✅ 结构、长度编码、往返一致性全部通过 |
| 畸形输入安全性 | 构造非法 DER | ✅ 返回原数据，不崩（与 ObjC 的防御分支一致） |
| ObjC 结构完整性 | 去注释后检查括号配平 | ✅ 4 个 .m / 4 个 .h 全部配平 |
| podspec 结构 | `do`/`end` 配平、必需字段 | ✅ |
| JS 产物 | `react-native bundle --platform ios` | ✅ 成功；旧 JS 桩已消失，三个原生模块名均被引用 |
| lint / 类型 | `eslint` / `tsc --noEmit` | ✅ 我改动的文件 0 问题 |

### DER 验证的关键结论

2048 位公钥：PKCS#1 269 B → SPKI 293 B，即**恰好 24 字节前缀**，与标准常量
`30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01 01 05 00 03 82 01 0F 00` 完全吻合。
私钥 PKCS#1 1316 B → PKCS#8 1342 B（26 字节前缀，含 version INTEGER）。

---

## 附：LXDER 的编译器级验证（已真实执行）

`LXDER.m` 是整批 ObjC 里唯一"纯算法、不依赖 UIKit/React"的部分，因此可以单独真编译。
做法：用 `zig cc`（Clang）把 `.m` 中的字节级逻辑逐语句移植为 C99 编译执行，
再用 **Node/OpenSSL 生成的真实密钥**做逐字节比对。

```
源码：D:\dsh\ios-audit\derc\lxder_test.c   （验证工具，不进仓库）
zig cc -std=c99 -Wall -Wextra -O1 -o lxder_test.exe lxder_test.c
node run_der_test.js
```

结果（RSA-1024 / 2048 / 3072 / 4096 全部通过）：

| 检查 | 结果 |
|---|---|
| 从 OpenSSL 的 SPKI 提取 PKCS#1 | ✅ 一致 |
| 从 OpenSSL 的 PKCS#8 提取 PKCS#1 | ✅ 一致 |
| PKCS#1 重新封装成 SPKI | ✅ **与 OpenSSL 输出逐字节相同** |
| PKCS#1 重新封装成 PKCS#8 | ✅ **与 OpenSSL 输出逐字节相同** |
| 畸形输入 | ✅ 返回原数据，不崩 |
| 短输入（<2 字节） | ✅ 不越界 |

这一步顺带抓出两个测试脚本自身的 bug（PKCS#8 里是私钥却拿公钥比对、变量被覆盖），
说明该测试确有判别力，不是"怎么写都过"。

> 边界：验证的是 DER 算法本身。`NSData` 胶水层与 `SecKeyCreateWithData` 的调用仍未经编译。

## 未验证（必须等真机 / macOS）

- **其余 ObjC 能否编译通过**：本机无 clang、无 Xcode、无 Apple SDK，只能靠人工审阅。
  这是当前最大的不确定性。
- 运行期行为：AES/RSA 实际加解密结果、通知授权回调、`getifaddrs` 取到的 IP。
- `CryptoModule` 的同步方法在 RN 0.73 旧架构下的实际可用性。

## 若编译失败的排查顺序

1. `CommonCrypto/*.h` 找不到 → 属正常，CommonCrypto 随 SDK 提供，检查是否被误加进 podspec 的 frameworks
2. `RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD` 报错 → 确认未开启新架构
3. `SecKeyCreateWithData` 返回 NULL → 密钥格式转换有问题，优先看 `LXDER.m`
4. podspec 找不到源文件 → 确认 `ios/LxModules/ios/` 层级与 `source_files` 的 glob 匹配

## 下一步

**P2：自定义源运行时（JavaScriptCore）**——这是"能不能真的听歌"的关键。
没有它，App 能启动、能看列表，但任何在线播放都会失败（`api-source-info.ts` 是空数组，无内置音源）。
