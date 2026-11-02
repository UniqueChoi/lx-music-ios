#import "AppDelegate.h"
#import <ReactNativeNavigation/ReactNativeNavigation.h>

#import <React/RCTBundleURLProvider.h>
#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // 必须在启动最早阶段配置音频会话，否则锁屏 / 切后台会立即停止播放。
  // 需与 Info.plist 的 UIBackgroundModes: audio 配合生效。
  [self setupAudioSession];

  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  [ReactNativeNavigation bootstrapWithBridge:bridge];
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return YES;
}

- (void)setupAudioSession
{
  NSError *error = nil;
  AVAudioSession *session = [AVAudioSession sharedInstance];

  // Playback：允许后台播放、锁屏继续播、支持蓝牙与控制中心
  BOOL ok = [session setCategory:AVAudioSessionCategoryPlayback
                            mode:AVAudioSessionModeDefault
                         options:AVAudioSessionCategoryOptionAllowBluetooth
                               | AVAudioSessionCategoryOptionAllowBluetoothA2DP
                               | AVAudioSessionCategoryOptionAllowAirPlay
                 error:&error];
  if (!ok) {
    NSLog(@"[AudioSession] setCategory failed: %@", error.localizedDescription);
  }

  error = nil;
  if (![session setActive:YES error:&error]) {
    NSLog(@"[AudioSession] setActive failed: %@", error.localizedDescription);
  }
}

- (NSArray<id<RCTBridgeModule>> *)extraModulesForBridge:(RCTBridge *)bridge {
  return [ReactNativeNavigation extraModulesForBridge:bridge];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self getBundleURL];
}
- (NSURL *)getBundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

@end
