//
//  LxMediaMetadata.h
//  iOS 版本地音频元数据读取（替代 Android 的 react-native-local-media-metadata）。
//
//  Android 版用 JAudioTagger 解析 mp3/flac/ogg 的标签；
//  iOS 侧用 AVFoundation 的 AVMetadataItem，支持系统能识别的容器与标签。
//
//  已知差异：
//   - iOS 不支持写回标签（writeMetadata / writePic / writeLyric 为 no-op 并 reject）
//   - flac/ogg 的标签解析依赖系统支持，部分字段可能为空
//

#import <React/RCTBridgeModule.h>

@interface LxMediaMetadata : NSObject <RCTBridgeModule>
@end
