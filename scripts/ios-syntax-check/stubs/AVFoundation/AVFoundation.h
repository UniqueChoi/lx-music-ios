/*
 * AVFoundation.h —— 语法检查桩（只含 LxMediaMetadata 用到的 API）
 */
#ifndef LX_STUB_AVFOUNDATION_H
#define LX_STUB_AVFOUNDATION_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

typedef NSString *AVMetadataKey;
typedef NSString *AVMetadataKeySpace;
typedef NSString *AVMediaType;
typedef NSString *AVFileType;

extern const AVMediaType AVMediaTypeAudio;
extern const AVMediaType AVMediaTypeVideo;

extern const AVMetadataKey AVMetadataCommonKeyTitle;
extern const AVMetadataKey AVMetadataCommonKeyArtist;
extern const AVMetadataKey AVMetadataCommonKeyAuthor;
extern const AVMetadataKey AVMetadataCommonKeyAlbumName;
extern const AVMetadataKey AVMetadataCommonKeyArtwork;

typedef NSInteger AVKeyValueStatus;
enum {
  AVKeyValueStatusUnknown = 0,
  AVKeyValueStatusLoading = 1,
  AVKeyValueStatusLoaded = 2,
  AVKeyValueStatusFailed = 3,
  AVKeyValueStatusCancelled = 4,
};

@class AVAsset;

@interface AVMetadataItem : NSObject
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) AVMetadataKey commonKey;
@property (readonly) id<NSObject> value;
@property (readonly) id dataValue;
@end

@interface AVAssetTrack : NSObject
@property (readonly) AVMediaType mediaType;
@property (readonly) float estimatedDataRate;
@end

@interface AVAsset : NSObject
@property (readonly) CMTime duration;
@property (readonly) NSArray<AVAssetTrack *> *tracks;
@property (readonly) NSArray<AVMetadataItem *> *commonMetadata;
@property (readonly) NSArray<NSString *> *availableMetadataFormats;
- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys
                      completionHandler:(void (^)(void))handler;
- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError **)outError;
- (NSArray<AVMetadataItem *> *)metadataForFormat:(NSString *)format;
@end

@interface AVURLAsset : AVAsset
+ (instancetype)URLAssetWithURL:(NSURL *)URL options:(NSDictionary *)options;
@end

#endif /* LX_STUB_AVFOUNDATION_H */
