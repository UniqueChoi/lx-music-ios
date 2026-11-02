//
//  LxUtilsModule.h
//  iOS 版 UtilsModule，接口与 android/.../utils/UtilsModule.java 保持一致，
//  使 src/utils/nativeModules/utils.ts 无需平台分支即可直接使用。
//
//  额外提供 pickDocument，用于替代 Android 的 SAF 文件选择
//  （自定义源导入、备份导入等都依赖它）。
//

#import <React/RCTEventEmitter.h>
#import <UIKit/UIKit.h>

@interface LxUtilsModule : RCTEventEmitter <RCTBridgeModule, UIDocumentPickerDelegate>
@end
