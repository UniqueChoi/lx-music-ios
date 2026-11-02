# P2 进度：自定义源运行时（JavaScriptCore）

> 目标：在 iOS 上跑通"自定义源脚本"，这是能否真正播放的关键。
> 没有它，App 能启动、能看列表，但任何在线播放都会失败
> （`src/utils/musicSdk/api-source-info.ts` 是空数组，开源版不内置任何音源）。

## 核心决策

**用系统自带 JavaScriptCore，而不是移植 QuickJS。**

依据：Android 的 QuickJS 宿主向脚本暴露的原生能力只有 **7 个函数**，
真正的 `lx.*` API 全部实现在 `user-api-preload.js`（21.9 KB 纯 JS，平台无关）。
所以 iOS 只需提供同样 7 个函数 + 一个 JSContext，预载脚本可原样复用。

## 交付内容

```
ios/LxModules/
  Resources/user-api-preload.js        ← 从 android/app/src/main/assets/script/ 复制（哈希一致）
  ios/LxUserApiModule.h / .m           ← JSC 宿主（约 400 行）
  ios/LXCryptoUtil.h / .m              ← AES/RSA/SHA1 共用实现（CryptoModule 与脚本运行时共享）
```

同时：
- `LxCryptoModule.m` 改为调用 `LXCryptoUtil`，消除两份重复的加解密代码
- 删除 `src/utils/nativeModules/userApi.ios.ts` 桩（原生模块已提供完整接口）
- podspec 增加 `JavaScriptCore` 框架与 `resource_bundles`

## 运行时契约（本阶段最重要产出）

### 宿主 → JS

| 调用 | 说明 |
|---|---|
| `lx_setup(key, id, name, description, version, author, homepage, rawScript)` | 8 个参数。**注意：预载脚本不执行 rawScript** |
| `__lx_native__(key, action, dataJSON)` | action ∈ `request` / `response` / `__set_timeout__` / `__run_error__` |

**执行顺序必须是**（照 QuickJS.java）：
```
注入 7 个全局函数 → evaluate(preload) → call lx_setup(...) → evaluate(源脚本)
```

### JS → 宿主

| 注入函数 | 返回值 |
|---|---|
| `__lx_native_call__(key, action, dataJSON)` | null |
| `__lx_native_call__utils_str2b64(str)` | base64 字符串 |
| `__lx_native_call__utils_b642buf(b64)` | **JSON 数组字符串**（脚本侧 `JSON.parse` 后转 Uint8Array） |
| `__lx_native_call__utils_str2md5(str)` | 小写 hex（入参已 encodeURIComponent，需先百分号解码） |
| `__lx_native_call__utils_aes_encrypt(data, key, iv, mode)` | base64 字符串 |
| `__lx_native_call__utils_rsa_encrypt(data, key, padding)` | base64 字符串 |
| `__lx_native_call__set_timeout(id, timeout)` | null。**参数是 (id, ms)**，超时后回调 `__lx_native__('__set_timeout__', id)` |

### 事件形状（极易写错的地方）

| 事件 | 形状 |
|---|---|
| `init` | `{action:'init', data:<JSON字符串>}`；失败时额外带顶层 `errorMessage` |
| `request` / `response` / `cancelRequest` / `showUpdateAlert` | `{action, data:<JSON字符串>}` |
| **`log`** | **`{action:'log', type, log}`——没有 `data` 字段** |

原因：`src/utils/nativeModules/userApi.ts` 里对 `event.data` 是**无条件** `JSON.parse` 的。
若把 log 也塞进 `data`（裸字符串），会在 JS 侧直接抛异常。

## 已验证

### 1. 契约行为验证（Node 模拟宿主，真实执行预载脚本）

用 `vm` 模块搭了一个宿主模拟器，加载**真实的** `user-api-preload.js` 并跑完整流程：

| 检查 | 结果 |
|---|---|
| 预载脚本加载、`lx_setup` 注入 | ✅ |
| `lx_setup` 后 `lx` 对象完整（EVENT_NAMES/request/send/on/utils/version/env） | ✅ |
| 一次性入口（`lx_setup`、`__lx_native_call__`）被正确清理 | ✅ |
| 源脚本 `lx.send('inited')` → 上报 sources 结构正确 | ✅ |
| `utils.buffer` 编解码往返 | ✅ |
| `utils.crypto.md5` 与 Node 结果一致 | ✅ |
| **完整 request 往返**（宿主触发 → 脚本 handler → HTTP → response → 回传 url） | ✅ |

完整往返验证的实际链路：
```
宿主 __lx_native__('request', {requestKey, data:{source,action,info}})
  → 脚本 handler 返回 Promise
    → lx.request() → nativeCall('request', {requestKey, url, options})
      → 宿主 HTTP → __lx_native__('response', {requestKey, error, response})
        → 脚本 resolve(url) → nativeCall('response', {status:true, result:{source,action,data:{type,url}}})
```

### 2. 此过程发现并修正的问题

- 我最初以为 `lx_setup` 会执行 `rawScript`——实际不会，必须单独 evaluate。**这是照 Java 源码才发现的**
- 源脚本 handler 必须**返回 Promise**（`handleRequest` 里 `.then(...)`），不是回调风格
- `log` 事件不是 `{action,data}` 形状
- `RCT_EXPORT_METHOD(sendAction:...` 少写一个 `)`，且 `loadScript` 漏了导出宏——被结构校验脚本抓出

### 3. 静态校验

| 检查 | 结果 |
|---|---|
| 全部 .h/.m 括号配平 | ✅ |
| JS ↔ ObjC 接口逐一比对 | ✅ Crypto 10/10、Utils 15/15、Cache 2/2、UserApi 3/3 |
| iOS bundle 重新打包 | ✅ 成功，旧桩已消失，`UserApiModule` / `api-action` 均被引用 |
| ESLint / tsc | ✅ 0 问题 |

### 4. 预载脚本的平台兼容性

审计结果：脚本**不依赖** `TextDecoder`（仅在注释中）、不依赖 `atob/btoa`（只是标识符名），
只用 ES6（Map/Set/Promise/Proxy/Object.defineProperty/globalThis）+ 自带 `utils.buffer`。
JavaScriptCore 全部支持，iOS 兼容性风险低。

## 未验证

- **ObjC 能否编译通过**——本机无 Xcode/Apple SDK，仍是最大不确定性
- JSC 的 block 桥接细节（`JSValue` 参数、返回值包装）未经真机验证
- 脚本资源能否被 `NSBundle` 正确找到（`resource_bundles` 的路径查找写了三级回退，但没实测）
- 真实源脚本（如第三方提供的 `*.js`）能否完整跑通

## 已知风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| JSC block 返回值类型不符预期 | 注入函数全失效 | 已按 `JSValue` 规范编写，且 `b642buf` 返回字符串（不是数组）以对齐 Java |
| `console` 每次调用都跨线程 emit | 脚本大量打日志时可能卡顿 | 已限制单条 4096 字符；可后续加节流 |
| preload 两份副本漂移 | iOS 与 Android 行为不一致 | 已记录哈希；建议加 CI 校验（见下） |

## 建议加的一致性校验

两份 `user-api-preload.js` 必须始终一致。建议在 `scripts/` 下加一个校验脚本，
或直接在 CI 里跑：

```powershell
$a = (Get-FileHash android/app/src/main/assets/script/user-api-preload.js).Hash
$b = (Get-FileHash ios/LxModules/Resources/user-api-preload.js).Hash
if ($a -ne $b) { throw 'preload 脚本已漂移' }
```

## 下一步

**P3：文件系统与本地音乐**（`fs.ios.ts` 已完成骨架，需补 UIDocumentPicker 与元数据读取）。
但在那之前，**P0–P2 的 ObjC 累积已约 1200 行未编译**，强烈建议先想办法编译一次。
