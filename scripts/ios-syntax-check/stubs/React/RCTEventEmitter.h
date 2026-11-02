/*
 * React/RCTEventEmitter.h 鈥斺€?璇硶妫€鏌ユ々
 */
#ifndef LX_STUB_RCTEVENTEMITTER_H
#define LX_STUB_RCTEVENTEMITTER_H

#import <React/RCTBridgeModule.h>

@interface RCTEventEmitter : NSObject <RCTBridgeModule>
- (void)sendEventWithName:(NSString *)eventName body:(id)body;
- (void)startObserving;
- (void)stopObserving;
- (NSArray<NSString *> *)supportedEvents;
@end

#endif /* LX_STUB_RCTEVENTEMITTER_H */
