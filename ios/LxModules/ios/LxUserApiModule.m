//
//  LxUserApiModule.m
//
//  实现要点（每一条都来自 Android 侧的实际行为，不是推测）：
//
//  1. 执行顺序必须与 QuickJS.java 一致：
//       注入 7 个全局函数 → evaluate(preload) → call lx_setup(...) → evaluate(源脚本)
//     注意 lx_setup 的 rawScript 参数预载脚本并不执行，源脚本要单独 evaluate。
//
//  2. 脚本必须运行在**单一线程**。JavaScriptCore 的 JSContext 不允许跨线程使用，
//     因此这里用一条串行队列 jsQueue 承载所有 JS 执行。
//
//  3. __lx_native_call__utils_b642buf 必须返回 **JSON 数组字符串**
//     （脚本侧是 `new Uint8Array(JSON.parse(...))`），不能返回二进制对象。
//
//  4. __lx_native_call__utils_str2md5 的入参是 encodeURIComponent 过的，
//     原生侧必须先做一次百分号解码（对应 Java 的 URLDecoder.decode）。
//
//  5. __lx_native_call__set_timeout 的参数顺序是 (id, timeout)，不是 (fn, ms)。
//     超时后通过 __lx_native__('__set_timeout__', id) 回调脚本。
//

#import "LxUserApiModule.h"
#import "LXCryptoUtil.h"
#import "LXDER.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>

static NSString *const kApiActionEvent = @"api-action";

@interface LxUserApiModule ()
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, strong) dispatch_queue_t jsQueue;
@property (nonatomic, strong) JSContext *context;
@property (nonatomic, copy) NSString *scriptKey;
@property (nonatomic, assign) BOOL isDestroyed;

- (void)emitDataAction:(NSString *)action jsonData:(nullable NSString *)jsonData;
- (void)emitLog:(NSString *)type message:(NSString *)message;
- (void)emitInitFailure:(NSString *)message;
- (NSString *)jsonEscape:(NSString *)text;
- (NSString *)loadPreloadScript;
- (void)injectNativeFunctionsIntoContext:(JSContext *)ctx;
- (void)callScriptWithAction:(NSString *)action data:(nullable NSString *)data;
- (void)reportExceptionIfNeeded;
- (void)tearDownContext;
- (JSValue *)makeConsoleWithContext:(JSContext *)ctx;
@end

@implementation LxUserApiModule

RCT_EXPORT_MODULE(UserApiModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (instancetype)init
{
  if (self = [super init]) {
    _jsQueue = dispatch_queue_create("cn.toside.lxmusic.userapi", DISPATCH_QUEUE_SERIAL);
    _isDestroyed = NO;
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[kApiActionEvent];
}

- (void)startObserving
{
  self.hasListeners = YES;
}

- (void)stopObserving
{
  self.hasListeners = NO;
}

#pragma mark - 预载脚本

- (NSString *)loadPreloadScript
{
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];

  // podspec 以 resource_bundles 形式打包时为 LxModules.bundle/user-api-preload.js
  NSURL *bundleURL = [bundle URLForResource:@"LxModules" withExtension:@"bundle"];
  if (bundleURL != nil) {
    NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleURL];
    NSURL *url = [resourceBundle URLForResource:@"user-api-preload" withExtension:@"js"];
    if (url != nil) return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
  }

  // 退回直接放在主 bundle 的情况
  NSURL *url = [bundle URLForResource:@"user-api-preload" withExtension:@"js"];
  if (url != nil) return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];

  NSURL *mainURL = [[NSBundle mainBundle] URLForResource:@"user-api-preload" withExtension:@"js"];
  if (mainURL != nil) return [NSString stringWithContentsOfURL:mainURL encoding:NSUTF8StringEncoding error:nil];

  return nil;
}

#pragma mark - 事件回传

// 普通事件：{ action, data: <JSON 字符串> }
// JS 侧 src/utils/nativeModules/userApi.ts 会对 data 无条件 JSON.parse，
// 所以这里传入的必须是合法 JSON 文本，不能是裸字符串。
- (void)emitDataAction:(NSString *)action jsonData:(nullable NSString *)jsonData
{
  if (!self.hasListeners) return;

  NSMutableDictionary *body = [NSMutableDictionary dictionary];
  body[@"action"] = action ?: @"";
  if (jsonData != nil) body[@"data"] = jsonData;

  [self sendEventWithName:kApiActionEvent body:body];
}

// 日志事件形状与 Java 的 JsHandler.sendLogEvent 一致：{ action:'log', type, log }
// 注意它没有 data 字段，因此不会被 JS 侧 JSON.parse。
- (void)emitLog:(NSString *)type message:(NSString *)message
{
  if (!self.hasListeners) return;

  [self sendEventWithName:kApiActionEvent body:@{
    @"action": @"log",
    @"type": type ?: @"log",
    @"log": message ?: @"",
  }];
}

// init 失败时额外带顶层 errorMessage，JS 侧会把它合并进 data
- (void)emitInitFailure:(NSString *)message
{
  if (!self.hasListeners) return;

  NSString *escaped = [self jsonEscape:message ?: @"unknown error"];
  NSString *jsonData = [NSString stringWithFormat:
    @"{\"info\":null,\"status\":false,\"errorMessage\":\"%@\"}", escaped];

  [self sendEventWithName:kApiActionEvent body:@{
    @"action": @"init",
    @"errorMessage": message ?: @"unknown error",
    @"data": jsonData,
  }];
}

#pragma mark - 7 个注入函数

- (void)injectNativeFunctionsIntoContext:(JSContext *)ctx
{
  __weak typeof(self) weakSelf = self;
  NSString *key = self.scriptKey;

  // 1) 脚本 → 宿主 的主通道
  ctx[@"__lx_native_call__"] = ^id(JSValue *callKey, JSValue *action, JSValue *data) {
    __strong typeof(weakSelf) self = weakSelf;
    if (self == nil) return [JSValue valueWithNullInContext:[JSContext currentContext]];

    if (![[callKey toString] isEqualToString:key]) {
      return [JSValue valueWithNullInContext:[JSContext currentContext]];
    }

    NSString *actionString = [action isString] ? [action toString] : @"";
    // 数据统一按字符串透传，与 Java 侧 new Object[]{action, data} 一致
    NSString *dataString = [data isString] ? [data toString] : nil;

    [self emitDataAction:actionString jsonData:dataString];
    return [JSValue valueWithNullInContext:[JSContext currentContext]];
  };

  // 2) 字符串 → base64
  ctx[@"__lx_native_call__utils_str2b64"] = ^id(JSValue *input) {
    NSString *text = [input toString];
    if (text == nil) return @"";
    NSData *utf8 = [text dataUsingEncoding:NSUTF8StringEncoding];
    return LXBase64Encode(utf8);
  };

  // 3) base64 → JSON 数组字符串（脚本侧 JSON.parse 后转 Uint8Array）
  ctx[@"__lx_native_call__utils_b642buf"] = ^id(JSValue *input) {
    NSString *text = [input toString];
    NSData *data = LXBase64Decode(text);
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *json = [NSMutableString stringWithCapacity:data.length * 4];
    [json appendString:@"["];
    for (NSUInteger i = 0; i < data.length; i++) {
      if (i > 0) [json appendString:@","];
      [json appendFormat:@"%d", (int)bytes[i]];
    }
    [json appendString:@"]"];
    return json;
  };

  // 4) MD5（入参已 encodeURIComponent，需先解码）
  ctx[@"__lx_native_call__utils_str2md5"] = ^id(JSValue *input) {
    NSString *encoded = [input toString];
    NSString *decoded = [encoded stringByRemovingPercentEncoding] ?: encoded;

    NSData *data = [decoded dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    return LXHexString([NSData dataWithBytes:digest length:CC_MD5_DIGEST_LENGTH]);
  };

  // 5) AES 加密
  ctx[@"__lx_native_call__utils_aes_encrypt"] = ^id(JSValue *data, JSValue *aesKey, JSValue *iv, JSValue *mode) {
    return LXAES([data toString] ?: @"",
                 [aesKey toString] ?: @"",
                 [iv isString] ? [iv toString] : @"",
                 [mode toString] ?: @"",
                 YES);
  };

  // 6) RSA 加密
  ctx[@"__lx_native_call__utils_rsa_encrypt"] = ^id(JSValue *data, JSValue *rsaKey, JSValue *padding) {
    return LXRSAPublicEncrypt([data toString] ?: @"",
                              [rsaKey toString] ?: @"",
                              [padding toString] ?: @"");
  };

  // 7) 定时器：参数顺序是 (id, timeout)
  ctx[@"__lx_native_call__set_timeout"] = ^id(JSValue *timeoutId, JSValue *timeout) {
    __strong typeof(weakSelf) self = weakSelf;
    if (self == nil) return [JSValue valueWithNullInContext:[JSContext currentContext]];

    NSString *identifier = [timeoutId toString];
    double delayMs = [timeout toDouble];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayMs * NSEC_PER_MSEC)),
                   self.jsQueue, ^{
      __strong typeof(weakSelf) self = weakSelf;
      if (self == nil) return;
      [self callScriptWithAction:@"__set_timeout__" data:identifier];
    });
    return [JSValue valueWithNullInContext:[JSContext currentContext]];
  };
}

#pragma mark - 调用脚本

- (void)callScriptWithAction:(NSString *)action data:(nullable NSString *)data
{
  if (self.context == nil) return;

  JSValue *nativeFn = self.context[@"__lx_native__"];
  if (nativeFn == nil || [nativeFn isUndefined]) return;

  NSMutableArray *args = [NSMutableArray arrayWithObjects:self.scriptKey, action, nil];
  if (data != nil) [args addObject:data];

  [nativeFn callWithArguments:args];
  [self reportExceptionIfNeeded];
}

- (void)reportExceptionIfNeeded
{
  JSValue *exception = self.context.exception;
  if (exception == nil || [exception isUndefined]) return;
  self.context.exception = nil;

  NSString *message = [exception toString] ?: @"unknown error";
  if (message.length > 1024) message = [[message substringToIndex:1024] stringByAppendingString:@"..."];
  [self emitLog:@"error" message:message];
}

#pragma mark - 生命周期

RCT_EXPORT_METHOD(loadScript:(NSDictionary *)info)
{
  NSString *script = info[@"script"];
  if (script == nil) {
    [self emitInitFailure:@"missing script"];
    return;
  }

  dispatch_async(self.jsQueue, ^{
    [self tearDownContext];

    self.isDestroyed = NO;
    self.scriptKey = [[NSUUID UUID] UUIDString];

    JSContext *ctx = [[JSContext alloc] init];
    self.context = ctx;

    // 脚本里的 console 输出转到 RN 日志，便于排查
    ctx[@"console"] = [self makeConsoleWithContext:ctx];

    [self injectNativeFunctionsIntoContext:ctx];

    NSString *preload = [self loadPreloadScript];
    if (preload == nil) {
      [self emitInitFailure:@"user-api-preload.js not found in bundle"];
      return;
    }

    [ctx evaluateScript:preload];
    [self reportExceptionIfNeeded];

    JSValue *lxSetup = ctx[@"lx_setup"];
    if (lxSetup == nil || [lxSetup isUndefined]) {
      [self emitInitFailure:@"lx_setup not found"];
      return;
    }

    // 与 QuickJS.java 相同：8 个参数，rawScript 一并传入（预载脚本仅存档，不执行）
    [lxSetup callWithArguments:@[
      self.scriptKey,
      info[@"id"] ?: @"",
      info[@"name"] ?: @"Unknown",
      info[@"description"] ?: @"",
      info[@"version"] ?: @"",
      info[@"author"] ?: @"",
      info[@"homepage"] ?: @"",
      script,
    ]];
    [self reportExceptionIfNeeded];

    // 关键：源脚本必须在 lx_setup 之后再单独执行
    [ctx evaluateScript:script];
    JSValue *exception = ctx.exception;
    if (exception != nil && ![exception isUndefined]) {
      ctx.exception = nil;
      NSString *message = [exception toString] ?: @"script error";
      if (message.length > 1024) message = [message substringToIndex:1024];

      [self callScriptWithAction:@"__run_error__" data:nil];
      [self emitInitFailure:message];
    }
  });
}

- (JSValue *)makeConsoleWithContext:(JSContext *)ctx
{
  // 与 Java 的 Console 行为一致：脚本里的 console.* 转成 log 事件上报，
  // 同时写一份系统日志便于真机排查。JS 侧据此在「错误日志」页面展示。
  __weak typeof(self) weakSelf = self;

  void (^forward)(NSString *, JSValue *) = ^(NSString *type, JSValue *arg) {
    __strong typeof(weakSelf) self = weakSelf;
    NSString *message = [arg toString] ?: @"";
    if (message.length > 4096) message = [[message substringToIndex:4096] stringByAppendingString:@"..."];
    NSLog(@"[UserApi][%@] %@", type, message);
    if (self == nil) return;
    // 直接派发到 JS 线程，避免从 JS 线程内再触发事件造成重入
    dispatch_async(dispatch_get_main_queue(), ^{
      [self emitLog:type message:message];
    });
  };

  return [JSValue valueWithObject:@{
    @"log": ^(JSValue *arg) { forward(@"log", arg); },
    @"info": ^(JSValue *arg) { forward(@"info", arg); },
    @"warn": ^(JSValue *arg) { forward(@"warn", arg); },
    @"error": ^(JSValue *arg) { forward(@"error", arg); },
  } inContext:ctx];
}

- (NSString *)jsonEscape:(NSString *)text
{
  NSMutableString *out = [NSMutableString stringWithString:text];
  [out replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, out.length)];
  [out replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, out.length)];
  [out replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, out.length)];
  [out replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:NSMakeRange(0, out.length)];
  [out replaceOccurrencesOfString:@"\t" withString:@"\\t" options:0 range:NSMakeRange(0, out.length)];
  return out;
}

- (void)tearDownContext
{
  if (self.context != nil) {
    self.context[@"console"] = nil;
    self.context = nil;
  }
}

#pragma mark - 对外方法

RCT_EXPORT_METHOD(sendAction:(NSString *)action
                       data:(NSString *)data)
{
  dispatch_async(self.jsQueue, ^{
    [self callScriptWithAction:action data:data];
  });
}

RCT_EXPORT_METHOD(destroy)
{
  dispatch_async(self.jsQueue, ^{
    self.isDestroyed = YES;
    [self tearDownContext];
  });
}

@end

