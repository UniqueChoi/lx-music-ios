/*
 * UniformTypeIdentifiers.h —— 语法检查桩
 */
#ifndef LX_STUB_UNIFORMTYPEIDENTIFIERS_H
#define LX_STUB_UNIFORMTYPEIDENTIFIERS_H

#import <Foundation/Foundation.h>

@interface UTType : NSObject
@end

/* ObjC 中这些是全局常量，不是类属性 */
extern UTType *const UTTypeItem;
extern UTType *const UTTypeData;
extern UTType *const UTTypeContent;
extern UTType *const UTTypeText;
extern UTType *const UTTypePlainText;
extern UTType *const UTTypeJSON;
extern UTType *const UTTypeAudio;

#endif /* LX_STUB_UNIFORMTYPEIDENTIFIERS_H */