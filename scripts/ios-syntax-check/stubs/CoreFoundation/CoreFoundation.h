/*
 * CoreFoundation.h —— 语法检查桩（只含本项目用到的类型与函数）
 */
#ifndef LX_STUB_COREFOUNDATION_H
#define LX_STUB_COREFOUNDATION_H

#include <stdbool.h>
#include <stdint.h>

typedef const void *CFTypeRef;
typedef const struct __CFData *CFDataRef;
typedef const struct __CFString *CFStringRef;
typedef const struct __CFDictionary *CFDictionaryRef;
typedef const struct __CFBoolean *CFBooleanRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef const struct __CFError *CFErrorRef;
typedef struct __CFError *CFMutableErrorRef;
typedef unsigned long CFOptionFlags;
typedef long CFIndex;
typedef bool Boolean;
typedef unsigned int CFStringEncoding;

extern const CFAllocatorRef kCFAllocatorDefault;
extern const CFBooleanRef kCFBooleanTrue;
extern const CFBooleanRef kCFBooleanFalse;

void CFRelease(CFTypeRef cf);
CFTypeRef CFRetain(CFTypeRef cf);
CFStringRef CFErrorCopyDescription(CFErrorRef err);

enum {
  kCFStringEncodingUTF8 = 0x08000100,
  kCFStringEncodingGB_18030_2000 = 0x0632
};

unsigned long CFStringConvertEncodingToNSStringEncoding(CFStringEncoding encoding);

#endif /* LX_STUB_COREFOUNDATION_H */
