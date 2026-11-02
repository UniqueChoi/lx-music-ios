//
//  LxCacheModule.m
//
//  Android 侧统计的是 cacheDir + externalCacheDir；iOS 对应沙盒的 Library/Caches。
//  注意不能清空 Documents（用户数据），只清 Caches + NSURLCache。
//

#import "LxCacheModule.h"

#import <Foundation/Foundation.h>

@implementation LxCacheModule

RCT_EXPORT_MODULE(CacheModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

static unsigned long long LXDirectorySize(NSString *path)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![manager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) return 0;

  unsigned long long total = 0;
  NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath:path];
  // 用 nextObject 而非 for-in：NSDirectoryEnumerator 不是集合类型，
  // 且需要在循环内调用 fileAttributes 取当前项属性。
  NSString *relative = nil;
  while ((relative = [enumerator nextObject]) != nil) {
    NSDictionary *attrs = [enumerator fileAttributes];
    if (attrs == nil) continue;
    if ([attrs[NSFileType] isEqualToString:NSFileTypeRegular]) {
      total += [attrs[NSFileSize] unsignedLongLongValue];
    }
  }
  return total;
}

RCT_EXPORT_METHOD(getAppCacheSize:(RCTPromiseResolveBlock)resolve
                         rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray<NSString *> *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                         NSUserDomainMask,
                                                                         YES);
    unsigned long long total = 0;
    for (NSString *path in cachePaths) {
      total += LXDirectorySize(path);
    }
    resolve(@(total));
  });
}

RCT_EXPORT_METHOD(clearAppCache:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSString *> *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                         NSUserDomainMask,
                                                                         YES);

    for (NSString *path in cachePaths) {
      NSArray<NSString *> *children = [manager contentsOfDirectoryAtPath:path error:nil];
      for (NSString *child in children) {
        NSString *full = [path stringByAppendingPathComponent:child];
        [manager removeItemAtPath:full error:nil];
      }
    }

    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    resolve(nil);
  });
}

@end
