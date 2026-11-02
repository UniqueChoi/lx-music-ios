//
//  LxUtilsModule.m
//
//  平台差异说明（这些不是"没做完"，而是 iOS 根本没有对应概念）：
//   - exitApp        iOS 不允许 App 主动退出，这里只做空实现（Apple HIG 明确反对 exit(0)）
//   - installApk     不存在 APK 概念，直接 reject
//   - 电池优化白名单  不存在，恒定返回 YES
//   - getSupportedAbis 只有 arm64
//   - 通知权限        Android 是跳系统设置页，iOS 是请求授权（UNUserNotificationCenter）
//

#import "LxUtilsModule.h"

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <sys/socket.h>

static NSString *const kScreenStateEvent = @"screen-state";
static NSString *const kWindowSizeEvent = @"screen-size-changed";

@interface LxUtilsModule ()
@property (nonatomic, assign) BOOL hasListeners;
@end

@implementation LxUtilsModule

RCT_EXPORT_MODULE(UtilsModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[kScreenStateEvent, kWindowSizeEvent];
}

- (void)startObserving
{
  self.hasListeners = YES;

  // 设备方向通知必须在主线程注册
  dispatch_async(dispatch_get_main_queue(), ^{
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleOrientationChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
  });
}

- (void)stopObserving
{
  self.hasListeners = NO;

  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
  });
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 窗口尺寸

static CGSize LXWindowSize(void)
{
  UIWindow *window = nil;
  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    for (UIWindow *candidate in windowScene.windows) {
      if (candidate.isKeyWindow) {
        window = candidate;
        break;
      }
    }
    if (window == nil && windowScene.windows.count > 0) {
      window = windowScene.windows.firstObject;
    }
    if (window != nil) break;
  }

  if (window != nil) return window.bounds.size;
  return [UIScreen mainScreen].bounds.size;
}

- (void)handleOrientationChange:(NSNotification *)notification
{
  if (!self.hasListeners) return;

 dispatch_async(dispatch_get_main_queue(), ^{
    CGSize size = LXWindowSize();
    [self sendEventWithName:kWindowSizeEvent body:@{@"width": @(size.width), @"height": @(size.height)}];
  });
}

/// 通知 JS 开始监听窗口尺寸变化（首次调用）
RCT_EXPORT_METHOD(listenWindowSizeChanged)
{
  // 观察者已在 startObserving 中注册，这里保留接口以对齐 Android 侧调用
}

RCT_EXPORT_METHOD(getWindowSize:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    CGSize size = LXWindowSize();
    resolve(@{@"width": @(size.width), @"height": @(size.height)});
  });
}

#pragma mark - 应用生命周期

RCT_EXPORT_METHOD(exitApp)
{
  // iOS 上不允许程序主动退出，交由系统处理
  NSLog(@"[LxUtilsModule] exitApp 在 iOS 上被忽略");
}

RCT_EXPORT_METHOD(getSupportedAbis:(RCTPromiseResolveBlock)resolve
                          rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@[@"arm64"]);
}

RCT_EXPORT_METHOD(installApk:(NSString *)filePath
             fileProviderAuthority:(NSString *)authority
                          resolver:(RCTPromiseResolveBlock)resolve
                          rejecter:(RCTPromiseRejectBlock)reject)
{
  reject(@"NOT_SUPPORTED", @"iOS 不支持安装 APK", nil);
}

#pragma mark - 屏幕常亮

RCT_EXPORT_METHOD(screenkeepAwake)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].idleTimerDisabled = YES;
  });
}

RCT_EXPORT_METHOD(screenUnkeepAwake)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
  });
}

#pragma mark - 设备信息

RCT_EXPORT_METHOD(getWIFIIPV4Address:(RCTPromiseResolveBlock)resolve
                            rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;

    if (getifaddrs(&interfaces) == 0) {
      // 优先取 en0（Wi-Fi），退而求其次取任意非回环 IPv4
      struct ifaddrs *cursor = interfaces;
      while (cursor != NULL) {
        if (cursor->ifa_addr != NULL && cursor->ifa_addr->sa_family == AF_INET) {
          NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
          if ([name isEqualToString:@"en0"]) {
            char buffer[INET_ADDRSTRLEN];
            struct sockaddr_in *addr = (struct sockaddr_in *)cursor->ifa_addr;
            if (inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer)) != NULL) {
              address = [NSString stringWithUTF8String:buffer];
              break;
            }
          }
        }
        cursor = cursor->ifa_next;
      }

      if (address == nil) {
        cursor = interfaces;
        while (cursor != NULL) {
          if (cursor->ifa_addr != NULL && cursor->ifa_addr->sa_family == AF_INET) {
            char buffer[INET_ADDRSTRLEN];
            struct sockaddr_in *addr = (struct sockaddr_in *)cursor->ifa_addr;
            NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
            if (![name isEqualToString:@"lo0"] &&
                inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer)) != NULL) {
              address = [NSString stringWithUTF8String:buffer];
              break;
            }
          }
          cursor = cursor->ifa_next;
        }
      }

      freeifaddrs(interfaces);
    }

    resolve(address ?: @"0.0.0.0");
  });
}

RCT_EXPORT_METHOD(getDeviceName:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    resolve([UIDevice currentDevice].name ?: @"Unknown");
  });
}

RCT_EXPORT_METHOD(getSystemLocales:(RCTPromiseResolveBlock)resolve
                          rejecter:(RCTPromiseRejectBlock)reject)
{
  // 输出格式与 Android 对齐：language_country，全部小写，例如 zh_cn
  NSArray<NSString *> *preferred = [NSLocale preferredLanguages];
  NSString *identifier = preferred.count > 0 ? preferred.firstObject : @"en";
  NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];

  NSString *language = [locale objectForKey:NSLocaleLanguageCode] ?: @"en";
  NSString *country = [locale objectForKey:NSLocaleCountryCode];

  if (country.length > 0) {
    resolve([NSString stringWithFormat:@"%@_%@", language.lowercaseString, country.lowercaseString]);
  } else {
    resolve(language.lowercaseString);
  }
}

#pragma mark - 通知权限

RCT_EXPORT_METHOD(isNotificationsEnabled:(RCTPromiseResolveBlock)resolve
                                rejecter:(RCTPromiseRejectBlock)reject)
{
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
    UNAuthorizationStatus status = settings.authorizationStatus;
    // 注意：不引用 UNAuthorizationStatusEphemeral（iOS 14+），以免在 13.4 部署目标下触发可用性告警
    BOOL enabled = (status == UNAuthorizationStatusAuthorized ||
                    status == UNAuthorizationStatusProvisional);
    resolve(@(enabled));
  }];
}

RCT_EXPORT_METHOD(openNotificationPermissionActivity:(RCTPromiseResolveBlock)resolve
                                            rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = (UNAuthorizationOptionAlert |
                                      UNAuthorizationOptionSound |
                                      UNAuthorizationOptionBadge);
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError *authError) {
      if (!granted && authError != nil) {
        NSLog(@"[LxUtilsModule] 通知授权失败: %@", authError.localizedDescription);
      }
      resolve(@(granted));
    }];
  });
}

#pragma mark - 分享

RCT_EXPORT_METHOD(shareText:(NSString *)shareTitle
                      title:(NSString *)title
                       text:(NSString *)text)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *root = [self topViewController];
    if (root == nil) return;

    NSMutableArray *items = [NSMutableArray array];
    if (text.length > 0) [items addObject:text];
    if (items.count == 0) return;

    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:items
                                                                             applicationActivities:nil];
    if (title.length > 0) controller.title = title;

    // iPad 上必须指定 popover 锚点，否则会崩
    if (controller.popoverPresentationController != nil) {
      controller.popoverPresentationController.sourceView = root.view;
      controller.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(root.view.bounds),
                                                                       CGRectGetMidY(root.view.bounds),
                                                                       0, 0);
    }

    [root presentViewController:controller animated:YES completion:nil];
  });
}

- (UIViewController *)topViewController
{
  UIWindow *window = nil;
  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    for (UIWindow *candidate in windowScene.windows) {
      if (candidate.isKeyWindow) {
        window = candidate;
        break;
      }
    }
    if (window != nil) break;
  }

  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController != nil) {
    controller = controller.presentedViewController;
  }
  return controller;
}

#pragma mark - 电池优化（iOS 无此概念）

RCT_EXPORT_METHOD(isIgnoringBatteryOptimization:(RCTPromiseResolveBlock)resolve
                                        rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@YES);
}

RCT_EXPORT_METHOD(requestIgnoreBatteryOptimization:(RCTPromiseResolveBlock)resolve
                                          rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@YES);
}

@end
