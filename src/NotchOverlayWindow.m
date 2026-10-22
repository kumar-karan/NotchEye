#import "NotchOverlayWindow.h"

@interface NotchOverlayWindow ()
@property (nonatomic, strong, readwrite) NotchIslandView *islandView;
@end

@implementation NotchOverlayWindow

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

- (instancetype)initOverlay {
    NSScreen *targetScreen = [self builtInOrMainScreen];
    NSRect windowRect = [self calculateOverlayRectForScreen:targetScreen];

    self = [super initWithContentRect:windowRect
                            styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [NSColor clearColor];
        self.hasShadow = NO;
        self.movable = NO;
        self.ignoresMouseEvents = YES;
        self.titleVisibility = NSWindowTitleHidden;
        self.titlebarAppearsTransparent = YES;
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        self.hidesOnDeactivate = NO;

        // Render above EVERYTHING, including Citrix full-screen remote desktop
        self.level = (NSWindowLevel)(CGShieldingWindowLevel() + 1);

        // Visible on all Spaces, full-screen spaces, and doesn't participate in Cmd+Tab / Exposé
        self.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                   NSWindowCollectionBehaviorFullScreenAuxiliary |
                                   NSWindowCollectionBehaviorStationary |
                                   NSWindowCollectionBehaviorIgnoresCycle);

        _islandView = [[NotchIslandView alloc] initWithFrame:NSMakeRect(0, 0, windowRect.size.width, windowRect.size.height)];
        self.contentView = _islandView;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenParametersChanged:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];

        [self orderFrontRegardless];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSScreen *)builtInOrMainScreen {
    for (NSScreen *screen in [NSScreen screens]) {
        NSDictionary *desc = [screen deviceDescription];
        NSNumber *screenNumber = desc[@"NSScreenNumber"];
        if (screenNumber && CGDisplayIsBuiltin([screenNumber unsignedIntValue])) {
            return screen;
        }
    }
    return [NSScreen mainScreen] ?: [NSScreen screens].firstObject;
}

- (NSRect)calculateOverlayRectForScreen:(NSScreen *)screen {
    CGFloat windowWidth = 340.0;
    CGFloat windowHeight = 90.0;

    CGFloat centerX = NSMidX(screen.frame);

    // If screen has a notch, align exactly with notch center
    if (@available(macOS 12.0, *)) {
        if (screen.auxiliaryTopLeftArea.size.width > 0 && screen.auxiliaryTopRightArea.size.width > 0) {
            CGFloat notchLeft = NSMaxX(screen.auxiliaryTopLeftArea);
            CGFloat notchRight = NSMinX(screen.auxiliaryTopRightArea);
            centerX = (notchLeft + notchRight) / 2.0;
        }
    }

    CGFloat originX = centerX - (windowWidth / 2.0);
    CGFloat originY = NSMaxY(screen.frame) - windowHeight;

    return NSMakeRect(originX, originY, windowWidth, windowHeight);
}

- (void)screenParametersChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSScreen *targetScreen = [self builtInOrMainScreen];
        NSRect newRect = [self calculateOverlayRectForScreen:targetScreen];
        [self setFrame:newRect display:YES];
        self.islandView.frame = NSMakeRect(0, 0, newRect.size.width, newRect.size.height);
        [self orderFrontRegardless];
    });
}

- (void)showCameraActiveWithAppName:(NSString *)appName {
    [self.islandView presentCameraActiveWithAppName:appName];
    [self orderFrontRegardless];
}

- (void)hideCameraActive {
    [self.islandView dismissCameraActive];
}

- (void)setTheme:(NotchEyeColorTheme)theme {
    [self.islandView updateTheme:theme];
}

@end
