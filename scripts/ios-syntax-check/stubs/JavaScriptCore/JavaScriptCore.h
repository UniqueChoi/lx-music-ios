/*
 * JavaScriptCore.h —— 语法检查桩（只含本项目用到的 API）
 */
#ifndef LX_STUB_JAVASCRIPTCORE_H
#define LX_STUB_JAVASCRIPTCORE_H

#import <Foundation/Foundation.h>

@class JSContext, JSValue, JSVirtualMachine;

@interface JSVirtualMachine : NSObject
@end

@interface JSContext : NSObject
+ (JSContext *)currentContext;
+ (JSValue *)currentThis;
- (instancetype)init;
- (instancetype)initWithVirtualMachine:(JSVirtualMachine *)vm;
- (JSValue *)evaluateScript:(NSString *)script;
- (JSValue *)evaluateScript:(NSString *)script withSourceURL:(NSURL *)url;
- (JSValue *)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id)key;
@property (strong) JSValue *exception;
@property (readonly) JSVirtualMachine *virtualMachine;
@property (copy) void (^exceptionHandler)(JSContext *context, JSValue *exception);
@end

@interface JSValue : NSObject
+ (JSValue *)valueWithObject:(id)value inContext:(JSContext *)context;
+ (JSValue *)valueWithBool:(BOOL)value inContext:(JSContext *)context;
+ (JSValue *)valueWithDouble:(double)value inContext:(JSContext *)context;
+ (JSValue *)valueWithInt32:(int32_t)value inContext:(JSContext *)context;
+ (JSValue *)valueWithUInt32:(uint32_t)value inContext:(JSContext *)context;
+ (JSValue *)valueWithNewObjectInContext:(JSContext *)context;
+ (JSValue *)valueWithNewArrayInContext:(JSContext *)context;
+ (JSValue *)valueWithNullInContext:(JSContext *)context;
+ (JSValue *)valueWithUndefinedInContext:(JSContext *)context;
- (JSValue *)callWithArguments:(NSArray *)arguments;
- (JSValue *)constructWithArguments:(NSArray *)arguments;
- (JSValue *)invokeMethod:(NSString *)method withArguments:(NSArray *)arguments;
- (JSValue *)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id)key;
- (BOOL)isUndefined;
- (BOOL)isNull;
- (BOOL)isBoolean;
- (BOOL)isNumber;
- (BOOL)isString;
- (BOOL)isObject;
- (BOOL)isArray;
- (BOOL)toBool;
- (double)toDouble;
- (int32_t)toInt32;
- (uint32_t)toUInt32;
- (NSString *)toString;
- (NSDictionary *)toDictionary;
- (NSArray *)toArray;
- (id)toObject;
@property (readonly) JSContext *context;
@end

#endif /* LX_STUB_JAVASCRIPTCORE_H */
