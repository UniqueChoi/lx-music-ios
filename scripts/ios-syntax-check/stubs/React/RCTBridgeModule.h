/*
 * React/RCTBridgeModule.h 鈥斺€?璇硶妫€鏌ユ々
 *
 * 鍏抽敭锛歊CT_EXPORT_METHOD 绛夊畯蹇呴』灞曞紑鎴愮湡姝ｇ殑 ObjC 鏂规硶澹版槑锛? *      鍚﹀垯鍚庨潰鐨勬柟娉曚綋涓嶄細琚В鏋愶紝璇硶妫€鏌ュ氨澶卞幓鎰忎箟銆? *      杩欓噷鐨勫睍寮€鏂瑰紡涓?React Native 0.73 鐨勫疄鐜扮瓑浠凤紙绠€鍖栦簡 RCTMethodInfo 閮ㄥ垎锛夈€? */
#ifndef LX_STUB_RCTBRIDGEMODULE_H
#define LX_STUB_RCTBRIDGEMODULE_H

#import <Foundation/Foundation.h>

typedef void (^RCTPromiseResolveBlock)(id result);
typedef void (^RCTPromiseRejectBlock)(NSString *code, NSString *message, NSError *error);

typedef struct RCTMethodInfo {
  const char *jsName;
  const char *objcName;
  const BOOL isSync;
} RCTMethodInfo;

@protocol RCTBridgeModule <NSObject>
@end

@protocol RCTBridgeModuleExport
@end

@class RCTBridge;

#define RCT_CONCAT2(A, B) A##B
#define RCT_CONCAT(A, B) RCT_CONCAT2(A, B)

#define RCT_DYNAMIC __attribute__((objc_method_family(none)))

#define _RCT_EXTERN_REMAP_METHOD(js_name, method, is_blocking_synchronous_method) \
  + (const RCTMethodInfo *)RCT_CONCAT(__rct_export__, RCT_CONCAT(__LINE__, __COUNTER__)) { \
    static RCTMethodInfo config = {#js_name, #method, is_blocking_synchronous_method}; \
    return &config; \
  }

#define RCT_EXPORT_METHOD(method) \
  _RCT_EXTERN_REMAP_METHOD(, method, NO) \
  - (void)method RCT_DYNAMIC

#define RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(method) \
  _RCT_EXTERN_REMAP_METHOD(, method, YES) \
  - (id)method RCT_DYNAMIC

#define RCT_REMAP_METHOD(js_name, method) \
  _RCT_EXTERN_REMAP_METHOD(js_name, method, NO) \
  - (void)method RCT_DYNAMIC

#define RCT_EXTERN extern __attribute__((visibility("default")))

#define RCT_EXPORT_MODULE(js_name) \
  RCT_EXTERN void RCTRegisterModule(Class); \
  + (NSString *)moduleName { return @#js_name; } \
  + (void)load { RCTRegisterModule(self); }

#define RCT_EXTERN_MODULE(objc_name, objc_supername) \
  objc_supername \
  @end \
  @interface objc_name : objc_supername \
  @end \
  @interface objc_name (RCTExternModule) <RCTBridgeModuleExport> \
  @end \
  @implementation objc_name (RCTExternModule) \
  RCT_EXPORT_MODULE()

#define RCT_EXTERN_METHOD(method) RCT_EXPORT_METHOD(method)

#if defined(__cplusplus)
extern "C" {
#endif
void RCTRegisterModule(Class moduleClass);
#if defined(__cplusplus)
}
#endif

#endif /* LX_STUB_RCTBRIDGEMODULE_H */
