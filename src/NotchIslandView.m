#import "NotchIslandView.h"
#import <QuartzCore/QuartzCore.h>

@interface NotchIslandView () {
    CALayer *_islandContainer;
    CAShapeLayer *_haloBorderLayer;
    CALayer *_dotLayer;
    CALayer *_dotPulseRing;
    CALayer *_iconLayer;
    CATextLayer *_titleLayer;
    CATextLayer *_subtitleLayer;
    CALayer *_liveBadgeLayer;
    CATextLayer *_liveBadgeText;

    NSTimer *_collapseTimer;
    BOOL _isCameraActive;
    NSRect _notchBaseFrame;
}
@end

@implementation NotchIslandView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = NotchEyeColorThemeGreen;
        _isExpanded = NO;
        _isHaloVisible = NO;
        _isCameraActive = NO;
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor clearColor].CGColor;
        [self setupSublayers];
    }
    return self;
}

- (NSColor *)accentColor {
    switch (_theme) {
        case NotchEyeColorThemeRed:
            // Alert Ruby P3 #FF3B30
            return [NSColor colorWithDisplayP3Red:1.0 green:0.231 blue:0.188 alpha:1.0];
        case NotchEyeColorThemeAmber:
            return [NSColor colorWithDisplayP3Red:1.0 green:0.620 blue:0.040 alpha:1.0];
        case NotchEyeColorThemeCyan:
            // CAD Cyan #38BDF8
            return [NSColor colorWithDisplayP3Red:0.220 green:0.741 blue:0.973 alpha:1.0];
        case NotchEyeColorThemeGreen:
        default:
            // Laser Green P3 #30D158
            return [NSColor colorWithDisplayP3Red:0.188 green:0.820 blue:0.345 alpha:1.0];
    }
}

- (void)setupSublayers {
    // 1. Island Container (Pitch Black Bezel Extension)
    _islandContainer = [CALayer layer];
    _islandContainer.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.98].CGColor;
    _islandContainer.cornerRadius = 18.0; // 18pt continuous corner radius per CAD spec
    if (@available(macOS 10.15, *)) {
        _islandContainer.cornerCurve = kCACornerCurveContinuous;
    }
    _islandContainer.masksToBounds = YES;
    _islandContainer.opacity = 0.0;
    _islandContainer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.10].CGColor;
    _islandContainer.borderWidth = 0.5;
    [self.layer addSublayer:_islandContainer];

    // 2. Halo bottom border (Calibrated 1.5pt Outer Laser Rim)
    _haloBorderLayer = [CAShapeLayer layer];
    _haloBorderLayer.fillColor = [NSColor clearColor].CGColor;
    _haloBorderLayer.strokeColor = [self accentColor].CGColor;
    _haloBorderLayer.lineWidth = 1.5;
    _haloBorderLayer.opacity = 0.0;
    _haloBorderLayer.shadowColor = [self accentColor].CGColor;
    _haloBorderLayer.shadowRadius = 8.0;
    _haloBorderLayer.shadowOpacity = 0.65;
    _haloBorderLayer.shadowOffset = CGSizeMake(0, -2);
    [self.layer addSublayer:_haloBorderLayer];

    // 3. Status Dot (Pulsing Indicator Micro-Dot)
    _dotLayer = [CALayer layer];
    _dotLayer.backgroundColor = [self accentColor].CGColor;
    _dotLayer.cornerRadius = 3.5;
    _dotLayer.shadowColor = [self accentColor].CGColor;
    _dotLayer.shadowRadius = 6.0;
    _dotLayer.shadowOpacity = 0.95;
    _dotLayer.shadowOffset = CGSizeZero;
    [_islandContainer addSublayer:_dotLayer];

    // 4. Dot Pulse Ring (1.2Hz Sine wave animation)
    _dotPulseRing = [CALayer layer];
    _dotPulseRing.borderColor = [self accentColor].CGColor;
    _dotPulseRing.borderWidth = 1.0;
    _dotPulseRing.cornerRadius = 8.0;
    _dotPulseRing.opacity = 0.0;
    [_islandContainer addSublayer:_dotPulseRing];

    // 5. Camera SF Symbol Icon
    _iconLayer = [CALayer layer];
    _iconLayer.contentsGravity = kCAGravityResizeAspect;
    if (@available(macOS 11.0, *)) {
        NSImage *camImg = [NSImage imageWithSystemSymbolName:@"video.fill" accessibilityDescription:nil];
        if (camImg) {
            NSImage *tinted = [self tintImage:camImg withColor:[self accentColor]];
            _iconLayer.contents = tinted;
        }
    }
    [_islandContainer addSublayer:_iconLayer];

    // 6. Title Text: "Camera Active"
    _titleLayer = [CATextLayer layer];
    _titleLayer.string = @"Camera Active";
    _titleLayer.font = (__bridge CFTypeRef)[NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
    _titleLayer.fontSize = 12.0;
    _titleLayer.foregroundColor = [NSColor whiteColor].CGColor;
    _titleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _titleLayer.alignmentMode = kCAAlignmentLeft;
    [_islandContainer addSublayer:_titleLayer];

    // 7. Subtitle Text: "Citrix HDX Pipe • corp-gateway"
    _subtitleLayer = [CATextLayer layer];
    _subtitleLayer.string = @"Citrix HDX Pipe";
    _subtitleLayer.font = (__bridge CFTypeRef)[NSFont monospacedSystemFontOfSize:10.0 weight:NSFontWeightMedium];
    _subtitleLayer.fontSize = 10.0;
    _subtitleLayer.foregroundColor = [NSColor colorWithWhite:0.65 alpha:1.0].CGColor;
    _subtitleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _subtitleLayer.alignmentMode = kCAAlignmentLeft;
    [_islandContainer addSublayer:_subtitleLayer];

    // 8. Live Badge Container + Text (High-contrast technical pill)
    _liveBadgeLayer = [CALayer layer];
    _liveBadgeLayer.backgroundColor = [[self accentColor] colorWithAlphaComponent:0.18].CGColor;
    _liveBadgeLayer.cornerRadius = 4.5;
    _liveBadgeLayer.borderColor = [[self accentColor] colorWithAlphaComponent:0.45].CGColor;
    _liveBadgeLayer.borderWidth = 0.5;
    [_islandContainer addSublayer:_liveBadgeLayer];

    _liveBadgeText = [CATextLayer layer];
    _liveBadgeText.string = @"LIVE";
    _liveBadgeText.font = (__bridge CFTypeRef)[NSFont monospacedSystemFontOfSize:8.5 weight:NSFontWeightBold];
    _liveBadgeText.fontSize = 8.5;
    _liveBadgeText.foregroundColor = [self accentColor].CGColor;
    _liveBadgeText.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _liveBadgeText.alignmentMode = kCAAlignmentCenter;
    [_liveBadgeLayer addSublayer:_liveBadgeText];
}

- (NSImage *)tintImage:(NSImage *)image withColor:(NSColor *)tintColor {
    NSImage *copied = [image copy];
    [copied lockFocus];
    [tintColor set];
    NSRect imageRect = NSMakeRect(0, 0, copied.size.width, copied.size.height);
    NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
    [copied unlockFocus];
    return copied;
}

- (void)layout {
    [super layout];
    [self updateLayoutFramesForExpanded:_isExpanded];
}

- (void)updateLayoutFramesForExpanded:(BOOL)expanded {
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;

    // Spec geometry:
    // Base Notch: 185pt width, 32pt height
    // Expanded Shield: 310pt width, 54pt height
    CGFloat containerWidth = expanded ? 310.0 : 185.0;
    CGFloat containerHeight = expanded ? 54.0 : 32.0;
    CGFloat containerX = (viewWidth - containerWidth) / 2.0;
    CGFloat containerY = viewHeight - containerHeight;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _islandContainer.frame = CGRectMake(containerX, containerY, containerWidth, containerHeight);
    _islandContainer.cornerRadius = expanded ? 18.0 : 14.0;

    // Continuous squircle bottom contour path (r=14pt squircle with ear fillets)
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat haloRadius = expanded ? 18.0 : 14.0;
    CGFloat haloLeft = containerX;
    CGFloat haloRight = containerX + containerWidth;
    CGFloat haloBottom = containerY;

    // Stroke along bottom rim
    CGPathMoveToPoint(path, NULL, haloLeft, containerY + 16);
    CGPathAddLineToPoint(path, NULL, haloLeft, haloBottom + haloRadius);
    CGPathAddArcToPoint(path, NULL, haloLeft, haloBottom, haloLeft + haloRadius, haloBottom, haloRadius);
    CGPathAddLineToPoint(path, NULL, haloRight - haloRadius, haloBottom);
    CGPathAddArcToPoint(path, NULL, haloRight, haloBottom, haloRight, haloBottom + haloRadius, haloRadius);
    CGPathAddLineToPoint(path, NULL, haloRight, containerY + 16);

    _haloBorderLayer.path = path;
    CGPathRelease(path);

    if (expanded) {
        // Dot + ring on left
        _dotLayer.frame = CGRectMake(16, 26, 7, 7);
        _dotPulseRing.frame = CGRectMake(11.5, 21.5, 16, 16);
        _iconLayer.frame = CGRectMake(13, 11, 14, 12);

        // Texts in center
        _titleLayer.frame = CGRectMake(36, 27, 200, 16);
        _subtitleLayer.frame = CGRectMake(36, 11, 200, 14);

        // LIVE Badge on right
        CGFloat badgeW = 34.0;
        CGFloat badgeH = 16.0;
        _liveBadgeLayer.frame = CGRectMake(containerWidth - badgeW - 14, 19, badgeW, badgeH);
        _liveBadgeText.frame = CGRectMake(0, 1.5, badgeW, badgeH);

        _dotLayer.opacity = 1.0;
        _iconLayer.opacity = 1.0;
        _titleLayer.opacity = 1.0;
        _subtitleLayer.opacity = 1.0;
        _liveBadgeLayer.opacity = 1.0;
    } else {
        // Collapsed mode: purely strokes the physical notch perimeter
        _dotLayer.opacity = 0.0;
        _iconLayer.opacity = 0.0;
        _titleLayer.opacity = 0.0;
        _subtitleLayer.opacity = 0.0;
        _liveBadgeLayer.opacity = 0.0;
    }

    [CATransaction commit];
}

#pragma mark - Public Presentation API

- (void)presentCameraActiveWithAppName:(NSString *)appName {
    _isCameraActive = YES;
    [_collapseTimer invalidate];
    _collapseTimer = nil;

    if (appName.length > 0) {
        _subtitleLayer.string = [NSString stringWithFormat:@"%@ • Session", appName];
    } else {
        _subtitleLayer.string = @"Citrix HDX Pipe";
    }

    [self updateTheme:_theme];

    _isExpanded = YES;
    _isHaloVisible = YES;

    // Spring(0.35s, bounce: 0.12) matching Blueprint Spec
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.35];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    _islandContainer.opacity = 1.0;
    _haloBorderLayer.opacity = 1.0;
    [self updateLayoutFramesForExpanded:YES];

    [CATransaction commit];

    // Start 1.2Hz sine wave pulse on dot
    [self startDotPulse];

    // Smoothly retract to 185pt hardware rim after 3.5 seconds
    __weak typeof(self) weakSelf = self;
    _collapseTimer = [NSTimer scheduledTimerWithTimeInterval:3.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf collapseToHalo];
    }];
}

- (void)collapseToHalo {
    if (!_isCameraActive) return;
    _isExpanded = NO;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.32];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

    // Retract container, keep continuous laser stroke glowing along notch bezel
    [self updateLayoutFramesForExpanded:NO];
    _islandContainer.opacity = 0.0;
    _haloBorderLayer.opacity = 1.0;

    [CATransaction commit];
}

- (void)dismissCameraActive {
    _isCameraActive = NO;
    _isExpanded = NO;
    _isHaloVisible = NO;
    [_collapseTimer invalidate];
    _collapseTimer = nil;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25];
    _islandContainer.opacity = 0.0;
    _haloBorderLayer.opacity = 0.0;
    [CATransaction commit];

    [_dotLayer removeAllAnimations];
    [_dotPulseRing removeAllAnimations];
}

- (void)startDotPulse {
    [_dotLayer removeAllAnimations];
    [_dotPulseRing removeAllAnimations];

    // 1.2Hz Sine pulse
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @(1.0);
    pulse.toValue = @(1.25);
    pulse.duration = 0.83; // ~1.2 Hz
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_dotLayer addAnimation:pulse forKey:@"pulse"];

    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @(0.85);
    ringScale.toValue = @(1.55);
    ringScale.duration = 1.66;
    ringScale.repeatCount = HUGE_VALF;

    CABasicAnimation *ringFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringFade.fromValue = @(0.75);
    ringFade.toValue = @(0.0);
    ringFade.duration = 1.66;
    ringFade.repeatCount = HUGE_VALF;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[ringScale, ringFade];
    group.duration = 1.66;
    group.repeatCount = HUGE_VALF;
    [_dotPulseRing addAnimation:group forKey:@"ring"];
}

- (void)updateTheme:(NotchEyeColorTheme)theme {
    _theme = theme;
    NSColor *color = [self accentColor];

    _haloBorderLayer.strokeColor = color.CGColor;
    _haloBorderLayer.shadowColor = color.CGColor;
    _dotLayer.backgroundColor = color.CGColor;
    _dotLayer.shadowColor = color.CGColor;
    _dotPulseRing.borderColor = color.CGColor;
    _liveBadgeText.foregroundColor = color.CGColor;
    _liveBadgeLayer.backgroundColor = [color colorWithAlphaComponent:0.18].CGColor;
    _liveBadgeLayer.borderColor = [color colorWithAlphaComponent:0.45].CGColor;

    if (@available(macOS 11.0, *)) {
        NSImage *camImg = [NSImage imageWithSystemSymbolName:@"video.fill" accessibilityDescription:nil];
        if (camImg) {
            _iconLayer.contents = [self tintImage:camImg withColor:color];
        }
    }
}

@end
