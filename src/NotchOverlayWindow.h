#import <AppKit/AppKit.h>
#import "NotchIslandView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NotchOverlayWindow : NSPanel

@property (nonatomic, strong, readonly) NotchIslandView *islandView;

- (instancetype)initOverlay;
- (void)showCameraActiveWithAppName:(NSString *)appName;
- (void)hideCameraActive;
- (void)setTheme:(NotchEyeColorTheme)theme;

@end

NS_ASSUME_NONNULL_END
