/*
 * UserNotifications.h —— 语法检查桩
 */
#ifndef LX_STUB_USERNOTIFICATIONS_H
#define LX_STUB_USERNOTIFICATIONS_H

#import <Foundation/Foundation.h>

typedef NSInteger UNAuthorizationStatus;
enum {
  UNAuthorizationStatusNotDetermined = 0,
  UNAuthorizationStatusDenied = 1,
  UNAuthorizationStatusAuthorized = 2,
  UNAuthorizationStatusProvisional = 3
};

typedef NSInteger UNAuthorizationOptions;
enum {
  UNAuthorizationOptionBadge = 1,
  UNAuthorizationOptionSound = 2,
  UNAuthorizationOptionAlert = 4
};

@interface UNNotificationSettings : NSObject
@property (readonly) UNAuthorizationStatus authorizationStatus;
@end

@interface UNUserNotificationCenter : NSObject
+ (UNUserNotificationCenter *)currentNotificationCenter;
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler;
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options
                      completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler;
@end

#endif /* LX_STUB_USERNOTIFICATIONS_H */
