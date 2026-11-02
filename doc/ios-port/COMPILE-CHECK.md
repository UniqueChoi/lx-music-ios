# iOS 原生代码的 Windows 编译验证

> 背景：正式 iOS 构建只能在 macOS + Xcode 上做。在此之前，
> `ios/LxModules/` 里的 Objective-C 代码没有任何反馈手段。
> 本方案用 **zig 自带的 clang + 手写 SDK 桩头文件**，在 Windows 上做真实编译。

## 一句话结论

**6 个 .m 文件全部编译通过，项目源码自身 0 error、0 warning。**
但这仍**不等于**能在真机上编译——差异见文末。

## 怎么跑

```powershell
# 前置：winget install zig.zig
powershell -ExecutionPolicy Bypass -File scripts\ios-syntax-check\check.ps1
```

输出：

```
OK    LxCacheModule.m
OK    LxCryptoModule.m
OK    LXCryptoUtil.m
OK    LXDER.m
OK    LxUserApiModule.m
OK    LxUtilsModule.m

全部 6 个文件编译通过（基于桩头文件）
```

## 原理

```
zig cc -c -x objective-c -fobjc-arc -fblocks -Wall -Wextra \
       -fobjc-runtime=macosx-10.15 \
       -I scripts/ios-syntax-check/stubs -I ios/LxModules/ios \
       -o out.o ios/LxModules/ios/Xxx.m
```

`scripts/ios-syntax-check/stubs/` 下手写了这些头文件：

| 桩 | 内容 |
|---|---|
| `Foundation/` | NSObject / NSString / NSData / NSArray / NSDictionary / NSError / NSFileManager / NSBundle / NSURLCache / NSSearchPath… |
| `CoreFoundation/` | CFDataRef / CFDictionaryRef / CFErrorRef / CFRelease / CFBridgingRelease |
| `UIKit/` | UIApplication / UIWindow / UIWindowScene / UIDevice / UIActivityViewController / CGRect… |
| `Security/` | SecKeyRef / SecKeyCreateWithData / kSecAttrKeyType… |
| `CommonCrypto/` | CCCrypt / CC_MD5 / CC_SHA1 / kCCOption… |
| `JavaScriptCore/` | JSContext / JSValue |
| `React/` | RCTBridgeModule / RCTEventEmitter + **宏展开成真实方法声明** |
| `dispatch/` | dispatch_queue_t（按 Apple 的做法定义为 ObjC 对象，才能用 `strong`） |
| `UserNotifications/`、`ifaddrs.h`、`arpa/inet.h`、`net/if.h`、`sys/socket.h` | 系统能力 |

关键点：`RCT_EXPORT_METHOD` 等宏必须**展开成真正的方法声明**，
否则方法体不会被解析，检查就形同虚设。

## 它真的能查出问题吗（判别力验证）

做过反向验证：故意在 `LxCacheModule.m` 里注入两类错误——

```objc
[self noSuchMethod];      // 拼错 selector
int x = @"str";           // 类型不匹配
```

编译器准确报出：

```
error: no visible @interface for 'LxCacheModule' declares the selector 'noSuchMethod'
error: incompatible pointer to integer conversion initializing 'int' with an expression of type 'NSString *'
```

说明这套检查不是「怎么写都过」。

## 这次实际抓到了什么

| 问题 | 性质 |
|---|---|
| `dispatch_queue_t` 用 `strong` 修饰报错 | 桩问题：Apple 上 dispatch_queue_t 是 ObjC 对象，已修正桩定义 |
| `[JSContext currentContext]`、`arrayWithObjects:` 未声明 | 桩缺口，补齐 |
| `nil` 传给 `NSError *__autoreleasing *` 报错 | **桩问题**：换成 `((void *)0)` 后全部通过，证明与源码无关 |
| `RCT_EXPORT_METHOD(sendAction:...)` 少一个 `)` | 早前被自写脚本抓到，编译器同样会报 |
| `loadScript` 漏了导出宏 | 同上 |

**结论：源码本身没有编译级错误。**之前担心的语法/拼写问题，这次基本可以排除。

## 它查不出什么（重要）

| 查不出 | 原因 |
|---|---|
| 与真实 Apple SDK 的**签名差异** | 桩是我按记忆写的，可能过宽或过窄 |
| 链接错误（符号缺失、重复） | 只编译到 `.o`，没链接 |
| 运行时行为 | 没有 ObjC runtime |
| 资源打包（`resource_bundles` 路径） | 与 pbxproj / CocoaPods 相关 |
| `pod install` 是否成功 | 需要 Ruby + CocoaPods |
| 头文件搜索顺序、模块化（`@import`） | 需要真实 SDK |
| 架构/ABI（arm64） | 目标是 x86_64-windows |

**所以：真机编译仍然必须做一次。**这次只是把「明显写错」这类问题提前排掉了。

## 维护注意

- 桩是按**当前用到的 API** 写的。新增未用过的 Foundation/UIKit API 时，
  可能需要在对应桩里补声明——报错通常是 `no visible @interface` 或 `unknown type name`。
- 桩里的 `nil` 定义为 `((void *)0)`，这是为了让 `nil` 能传给 `NSError **`。
  真实 SDK 里 `nil` 是 `((id)0)`，clang 另有特殊处理。
- `scripts/ios-syntax-check/check.ps1` 必须是 **UTF-8 with BOM**，
  否则 Windows PowerShell 5.1 会把中文读成乱码并导致语法错误。
