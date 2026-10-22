#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NotchEyeColorTheme) {
    NotchEyeColorThemeGreen = 0,   // #30D158 (Laser Green / P3 Normal)
    NotchEyeColorThemeRed   = 1,   // #FF3B30 (Alert Ruby / P3 Critical VDI)
    NotchEyeColorThemeAmber = 2,   // #FF9E0A (Privacy Amber)
    NotchEyeColorThemeCyan  = 3    // #38BDF8 (CAD / DaVinci Cyan)
};

@interface NotchIslandView : NSView

@property (nonatomic, assign) NotchEyeColorTheme theme;
@property (nonatomic, assign, readonly) BOOL isExpanded;
@property (nonatomic, assign, readonly) BOOL isHaloVisible;

- (void)presentCameraActiveWithAppName:(NSString *)appName;
- (void)dismissCameraActive;
- (void)updateTheme:(NotchEyeColorTheme)theme;

@end

NS_ASSUME_NONNULL_END
