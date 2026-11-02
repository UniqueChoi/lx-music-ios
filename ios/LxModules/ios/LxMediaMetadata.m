//
//  LxMediaMetadata.m
//
//  用 AVFoundation 读取本地音频文件的元数据，接口与 Android 的
//  react-native-local-media-metadata 保持一致（见 src/utils/localMediaMetadata.ts）。
//
//  实现要点：
//   1. AVURLAsset 的 duration / tracks 等属性用同步访问，在 iOS 13 上会触发
//      主线程告警且对网络资源不可靠；这里统一放到后台队列并用
//      loadValuesAsynchronouslyForKeys 预加载。
//   2. commonMetadata 只包含「通用」标签；部分容器（如 flac）的中文标签
//      可能只在 format-specific metadata 里，故两者都扫一遍。
//   3. readPic 需要把封面数据写到磁盘再返回路径（与 Android 行为一致），
//      JS 侧会自己加 file:// 前缀。
//

#import "LxMediaMetadata.h"

#import <AVFoundation/AVFoundation.h>

@implementation LxMediaMetadata

RCT_EXPORT_MODULE(LocalMediaModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

#pragma mark - 工具

static NSString *LXStringFromMetadataItem(AVMetadataItem *item)
{
  id<NSObject> value = item.value;
  if (value == nil) return nil;

  if ([value isKindOfClass:[NSString class]]) {
    return (NSString *)value;
  }

  // 部分标签是 NSData，需要按 UTF-8 解码
  if ([value isKindOfClass:[NSData class]]) {
    NSString *decoded = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
    if (decoded != nil) return decoded;
  }

  // 其他类型（NSNumber 等）统一转字符串
  NSString *desc = [(NSObject *)value description];
  return desc;
}

/// 从 commonMetadata 中按 key 取第一个非空字符串
static NSString *LXValueForKey(NSArray<AVMetadataItem *> *items, NSString *key)
{
  for (AVMetadataItem *item in items) {
    if (![item.commonKey isEqualToString:key]) continue;
    NSString *str = LXStringFromMetadataItem(item);
    if (str.length > 0) return str;
  }
  return nil;
}

/// 在 format-specific metadata 里按常见 key 找值（很多格式不用 commonKey）
static NSString *LXValueForRawKeys(NSArray<AVMetadataItem *> *items, NSArray<NSString *> *keys)
{
  NSArray<NSString *> *lowerKeys = ({
    NSMutableArray *arr = [NSMutableArray array];
    for (NSString *k in keys) [arr addObject:k.lowercaseString];
    arr;
  });

  for (AVMetadataItem *item in items) {
    NSString *identifier = item.identifier ?: @"";
    // 常见标识形如 "mdta/title"、"©nam"、"©ART"
    NSString *lowerIdentifier = identifier.lowercaseString;
    BOOL matched = NO;
    for (NSString *k in lowerKeys) {
      if ([lowerIdentifier containsString:k]) { matched = YES; break; }
    }
    if (!matched) continue;

    NSString *str = LXStringFromMetadataItem(item);
    if (str.length > 0) return str;
  }
  return nil;
}

/// 用扩展名推断容器类型，与 Android 返回的 type/ext 字段对齐
static NSString *LXFileExtension(NSString *path)
{
  NSString *ext = path.pathExtension.lowercaseString;
  if (ext.length > 0) return ext;
  return @"mp3";
}

#pragma mark - readMetadata

RCT_EXPORT_METHOD(readMetadata:(NSString *)filePath
                     resolver:(RCTPromiseResolveBlock)resolve
                     rejecter:(RCTPromiseRejectBlock)reject)
{
  if (filePath.length == 0) {
    resolve([NSNull null]);
    return;
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSURL *url = [NSURL fileURLWithPath:filePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

    // 同步等待元数据可用（已在后台队列，不会卡主线程）
    NSArray<NSString *> *keys = @[@"duration", @"tracks", @"commonMetadata", @"availableMetadataFormats"];
    for (NSString *key in keys) {
      NSError *error = nil;
      // 真实 API 只有 completionHandler 版本；这里传 NULL 表示不关心回调，
      // 下一行的 statusOfValueForKey 会同步返回当前状态。
      [asset loadValuesAsynchronouslyForKeys:@[key] completionHandler:NULL];
      AVKeyValueStatus status = [asset statusOfValueForKey:key error:&error];
      if (status == AVKeyValueStatusFailed) {
        resolve([NSNull null]);
        return;
      }
    }

    // 读取时长
    NSTimeInterval interval = 0;
    if (asset.duration.timescale != 0) {
      interval = CMTimeGetSeconds(asset.duration);
    }
    if (!isfinite(interval) || interval < 0) interval = 0;

    // 汇总所有可用格式的元数据
    NSMutableArray<AVMetadataItem *> *allItems = [NSMutableArray array];
    [allItems addObjectsFromArray:asset.commonMetadata];
    for (NSString *format in asset.availableMetadataFormats) {
      [allItems addObjectsFromArray:[asset metadataForFormat:format]];
    }

    NSString *title = LXValueForKey(asset.commonMetadata, AVMetadataCommonKeyTitle)
      ?: LXValueForRawKeys(allItems, @[@"title", @"©nam", @"nam"]);
    NSString *artist = LXValueForKey(asset.commonMetadata, AVMetadataCommonKeyArtist)
      ?: LXValueForKey(asset.commonMetadata, AVMetadataCommonKeyAuthor)
      ?: LXValueForRawKeys(allItems, @[@"artist", @"©art", @"art", @"author"]);
    NSString *album = LXValueForKey(asset.commonMetadata, AVMetadataCommonKeyAlbumName)
      ?: LXValueForRawKeys(allItems, @[@"album", @"©alb", @"alb"]);

    // 没有标题时退回文件名（与大多数播放器行为一致）
    if (title.length == 0) {
      title = [filePath.lastPathComponent stringByDeletingPathExtension];
    }

    // 估算码率：优先用音频轨的 estimatedDataRate
    NSInteger bitrate = 0;
    NSArray<AVAssetTrack *> *tracks = asset.tracks;
    for (AVAssetTrack *track in tracks) {
      if (![track.mediaType isEqualToString:AVMediaTypeAudio]) continue;
      float rate = track.estimatedDataRate;
      if (rate > 0) {
        bitrate = (NSInteger)(rate / 1000.0);
        break;
      }
    }

    // 文件大小
    NSNumber *size = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    if (attrs != nil) size = attrs[NSFileSize];

    NSString *ext = LXFileExtension(filePath);

    resolve(@{
      @"type": ext,
      @"ext": ext,
      @"interval": @(interval),
      @"bitrate": bitrate > 0 ? [NSString stringWithFormat:@"%ld", (long)bitrate] : @"",
      @"size": size ?: @0,
      @"name": title ?: @"",
      @"singer": artist ?: @"",
      @"albumName": album ?: @"",
    });
  });
}

#pragma mark - readPic

/// 把封面写到 picDir 下，返回文件路径；没有封面返回空字符串
RCT_EXPORT_METHOD(readPic:(NSString *)filePath
                   picDir:(NSString *)picDir
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];

    NSError *error = nil;
    [asset loadValuesAsynchronouslyForKeys:@[@"commonMetadata"] completionHandler:NULL];
    if ([asset statusOfValueForKey:@"commonMetadata" error:&error] == AVKeyValueStatusFailed) {
      resolve(@"");
      return;
    }

    NSMutableArray<AVMetadataItem *> *items = [NSMutableArray arrayWithArray:asset.commonMetadata];
    for (NSString *format in asset.availableMetadataFormats) {
      [items addObjectsFromArray:[asset metadataForFormat:format]];
    }

    NSData *artwork = nil;
    for (AVMetadataItem *item in items) {
      if (![item.commonKey isEqualToString:AVMetadataCommonKeyArtwork]) continue;
      id<NSObject> value = item.value;
      if ([value isKindOfClass:[NSData class]]) {
        artwork = (NSData *)value;
        break;
      }
      // 某些容器把封面放在 dataValue 里
      if ([item.dataValue isKindOfClass:[NSData class]]) {
        artwork = item.dataValue;
        break;
      }
    }

    if (artwork.length == 0) {
      resolve(@"");
      return;
    }

    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:picDir withIntermediateDirectories:YES attributes:nil error:nil];

    // 用源文件名做 key，避免重复解析同一文件
    NSString *baseName = filePath.lastPathComponent;
    NSString *target = [picDir stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"%@.jpg", baseName]];

    // 已存在则直接复用
    if ([manager fileExistsAtPath:target]) {
      resolve(target);
      return;
    }

    if (![artwork writeToFile:target atomically:YES]) {
      resolve(@"");
      return;
    }
    resolve(target);
  });
}

#pragma mark - readLyric

RCT_EXPORT_METHOD(readLyric:(NSString *)filePath
              isReadLrcFile:(BOOL)isReadLrcFile
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // 1) 优先读同名 .lrc 文件
    if (isReadLrcFile) {
      NSString *lrcPath = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"lrc"];
      NSString *content = [NSString stringWithContentsOfFile:lrcPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
      if (content.length == 0) {
        // 兼容 GBK 编码的老歌词文件
        NSData *data = [NSData dataWithContentsOfFile:lrcPath];
        if (data.length > 0) {
          NSStringEncoding gbk = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
          content = [[NSString alloc] initWithData:data encoding:gbk];
        }
      }
      if (content.length > 0) {
        resolve(content);
        return;
      }
    }

    // 2) 读音频内嵌歌词（USLT 帧，AVFoundation 通常映射到 commonKey 之外）
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];
    [asset loadValuesAsynchronouslyForKeys:@[@"availableMetadataFormats"] completionHandler:NULL];

    NSArray<NSString *> *lyricKeys = @[@"lyric", @"unsyncedlyrics", @"©lyr", @"uslt"];
    for (NSString *format in asset.availableMetadataFormats) {
      for (AVMetadataItem *item in [asset metadataForFormat:format]) {
        NSString *identifier = (item.identifier ?: @"").lowercaseString;
        BOOL matched = NO;
        for (NSString *k in lyricKeys) {
          if ([identifier containsString:k]) { matched = YES; break; }
        }
        if (!matched) continue;

        NSString *text = LXStringFromMetadataItem(item);
        if (text.length > 0) {
          resolve(text);
          return;
        }
      }
    }

    resolve(@"");
  });
}

#pragma mark - 写入（iOS 暂不支持）

RCT_EXPORT_METHOD(writeMetadata:(NSString *)filePath
                       metadata:(NSDictionary *)metadata
                    isOverwrite:(BOOL)isOverwrite
                       resolver:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject)
{
  reject(@"NOT_SUPPORTED", @"iOS 版本暂不支持写回音频标签", nil);
}

RCT_EXPORT_METHOD(writePic:(NSString *)filePath
                   picPath:(NSString *)picPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  reject(@"NOT_SUPPORTED", @"iOS 版本暂不支持写回封面", nil);
}

RCT_EXPORT_METHOD(writeLyric:(NSString *)filePath
                     lyric:(NSString *)lyric
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  // 歌词可以直接写成同名 .lrc 文件，这个是可行的
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *lrcPath = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"lrc"];
    NSError *error = nil;
    BOOL ok = [lyric writeToFile:lrcPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
      reject(@"WRITE_FAILED", error.localizedDescription ?: @"写入歌词失败", error);
      return;
    }
    resolve(nil);
  });
}

@end
