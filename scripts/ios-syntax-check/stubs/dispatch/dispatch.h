/*
 * dispatch/dispatch.h —— 语法检查桩
 */
#ifndef LX_STUB_DISPATCH_H
#define LX_STUB_DISPATCH_H

#include <stdint.h>

/*
 * libdispatch 在 Apple 平台上把 dispatch_queue_t 定义为 ObjC 对象类型
 * （OS_OBJECT_USE_OBJC=1），因此可以用 strong 修饰。
 * 这里保持一致，否则 @property(strong) dispatch_queue_t 会误报。
 */
@class OS_dispatch_queue;
typedef OS_dispatch_queue *dispatch_queue_t;
typedef struct dispatch_semaphore_s *dispatch_semaphore_t;
typedef uint64_t dispatch_time_t;
typedef long dispatch_queue_priority_t;
typedef void (^dispatch_block_t)(void);
typedef struct dispatch_queue_attr_s *dispatch_queue_attr_t;

static const long DISPATCH_QUEUE_PRIORITY_DEFAULT = 0;
static const long DISPATCH_QUEUE_PRIORITY_HIGH = 2;
static const long DISPATCH_QUEUE_PRIORITY_LOW = -2;
static const long DISPATCH_QUEUE_PRIORITY_BACKGROUND = -32768;

#define DISPATCH_QUEUE_SERIAL ((dispatch_queue_t)0)
#define DISPATCH_TIME_NOW 0ull
#define DISPATCH_TIME_FOREVER (~0ull)
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
#define USEC_PER_SEC 1000000ull

dispatch_queue_t dispatch_get_main_queue(void);
dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
dispatch_queue_t dispatch_queue_create(const char *label, void *attr);
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_once_stub(void);

dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);

#endif /* LX_STUB_DISPATCH_H */
