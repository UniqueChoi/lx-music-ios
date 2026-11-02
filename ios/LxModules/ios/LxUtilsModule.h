//
//  LxUtilsModule.h
//  iOS 版 UtilsModule，接口与 android/.../utils/UtilsModule.java 保持一致，
//  使 src/utils/nativeModules/utils.ts 无需平台分支即可直接使用。
//

#import <React/RCTEventEmitter.h>

@interface LxUtilsModule : RCTEventEmitter <RCTBridgeModule>
@end
