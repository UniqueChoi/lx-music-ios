/*
 * UIKit.h —— 语法检查桩（只含本项目用到的 API）
 */
#ifndef LX_STUB_UIKIT_H
#define LX_STUB_UIKIT_H

#import <Foundation/Foundation.h>

typedef double CGFloat;

typedef struct CGPoint { CGFloat x, y; } CGPoint;
typedef struct CGSize { CGFloat width, height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;

static inline CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
  CGRect r; r.origin.x = x; r.origin.y = y; r.size.width = w; r.size.height = h; return r;
}
static inline CGSize CGSizeMake(CGFloat w, CGFloat h) { CGSize s; s.width = w; s.height = h; return s; }
static inline CGPoint CGPointMake(CGFloat x, CGFloat y) { CGPoint p; p.x = x; p.y = y; return p; }
static inline CGFloat CGRectGetMidX(CGRect r) { return r.origin.x + r.size.width / 2.0; }
static inline CGFloat CGRectGetMidY(CGRect r) { return r.origin.y + r.size.height / 2.0; }
static inline CGFloat CGRectGetWidth(CGRect r) { return r.size.width; }

typedef struct UIEdgeInsets { CGFloat top, left, bottom, right; } UIEdgeInsets;

@class UIWindow, UIViewController, UIScreen, UIScene, UIWindowScene, UIActivityViewController;
@class UIColor, UIFont, UIImage, UIView;

typedef NSInteger UIInterfaceOrientation;
typedef NSInteger UIUserInterfaceIdiom;

@interface UIColor : NSObject
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
+ (UIColor *)whiteColor;
+ (UIColor *)blackColor;
@end

@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
@property (readonly) CGRect bounds;
@property (readonly) CGFloat scale;
@end

@interface UIResponder : NSObject
@end

@interface UIView : UIResponder
@property CGRect bounds;
@property CGRect frame;
@property (strong) UIColor *backgroundColor;
@end

@interface UIViewController : UIResponder
@property (strong) UIView *view;
@property (readonly) UIViewController *presentedViewController;
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;
@end

@interface UIWindow : UIView
@property (readonly) UIViewController *rootViewController;
@property (readonly, getter=isKeyWindow) BOOL keyWindow;
@property (readonly) UIWindowScene *windowScene;
@end

@interface UIApplication : UIResponder
+ (UIApplication *)sharedApplication;
@property (readonly) NSSet<UIScene *> *connectedScenes;
@property (getter=isIdleTimerDisabled) BOOL idleTimerDisabled;
- (BOOL)openURL:(NSURL *)url;
@property (readonly) UIWindow *keyWindow;
@end

@interface UIScene : NSObject
@property (readonly) UIApplication *delegate;
@end

@interface UIWindowScene : UIScene
@property (readonly) NSArray<UIWindow *> *windows;
@end

@interface UIDevice : NSObject
+ (UIDevice *)currentDevice;
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *systemVersion;
@property (readonly) UIUserInterfaceIdiom userInterfaceIdiom;
- (void)beginGeneratingDeviceOrientationNotifications;
- (void)endGeneratingDeviceOrientationNotifications;
@end

extern NSString *const UIDeviceOrientationDidChangeNotification;

@interface UIPopoverPresentationController : NSObject
@property (strong, nullable) UIView *sourceView;
@property CGRect sourceRect;
@end

@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities;
@property (readonly) UIPopoverPresentationController *popoverPresentationController;
@property (copy, nullable) NSString *title;
@end

typedef NSInteger UIDocumentPickerMode;
enum {
  UIDocumentPickerModeImport = 0,
  UIDocumentPickerModeOpen = 1,
  UIDocumentPickerModeExportToService = 2,
  UIDocumentPickerModeMoveToService = 3
};

typedef NSInteger UIModalPresentationStyle;
static const UIModalPresentationStyle UIModalPresentationFormSheet = 2;

@class UIDocumentPickerViewController;
@protocol UIDocumentPickerDelegate <NSObject>
@optional
- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls;
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller;
@end

@interface UIDocumentPickerViewController : UIViewController
- (instancetype)initForOpeningContentTypes:(NSArray *)contentTypes
                                    asCopy:(BOOL)asCopy;
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)allowedUTIs
                               inMode:(UIDocumentPickerMode)mode;
@property (weak, nullable) id<UIDocumentPickerDelegate> delegate;
@property (assign) BOOL allowsMultipleSelection;
@property (assign) UIModalPresentationStyle modalPresentationStyle;
@end
#endif /* LX_STUB_UIKIT_H */
