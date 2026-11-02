//
//  LxUserApiModule.h
//  iOS 版自定义源脚本运行时（替代 Android 的 QuickJS 实现）。
//
//  与 android/.../userApi/ 的契约完全一致：
//   - 宿主 → JS：lx_setup(...)、__lx_native__(key, action, data)
//   - JS → 宿主：__lx_native_call__(key, action, data) 及 6 个 utils_* 注入函数
//   - 事件名：api-action，body = { action, data }
//

#import <React/RCTEventEmitter.h>

@interface LxUserApiModule : RCTEventEmitter <RCTBridgeModule>
@end
