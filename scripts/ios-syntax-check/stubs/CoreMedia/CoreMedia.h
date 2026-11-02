/*
 * CoreMedia.h —— 语法检查桩（CMTime 及常用函数）
 */
#ifndef LX_STUB_COREMEDIA_H
#define LX_STUB_COREMEDIA_H

#include <stdint.h>

typedef int64_t CMTimeValue;
typedef int32_t CMTimeScale;
typedef uint32_t CMTimeFlags;

typedef struct {
  CMTimeValue value;
  CMTimeScale timescale;
  CMTimeFlags flags;
  CMTimeValue epoch;
} CMTime;

double CMTimeGetSeconds(CMTime time);
CMTime CMTimeMake(int64_t value, int32_t timescale);

#endif /* LX_STUB_COREMEDIA_H */
