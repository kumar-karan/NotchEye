#import "NotchIslandView.h"
#import <QuartzCore/QuartzCore.h>

@interface NotchIslandView () {
    CAShapeLayer *_backgroundShapeLayer;
    CAShapeLayer *_haloStrokeLayer;
    
    // Left element: circular glyph container
    CALayer *_iconBadgeLayer;
    CALayer *_iconLayer;
    CALayer *_statusDotLayer;
    CALayer *_statusDotPulseLayer;

    // Center typography: SF Pro Display
    CATextLayer *_titleLayer;
    CATextLayer *_subtitleLayer;

    // Right element: Apple-style status capsule
    CALayer *_badgeContainer;
    CATextLayer *_badgeTextLayer;

    NSTimer *_collapseTimer;
    BOOL _isCameraActive;
}
@end

@implementation NotchIslandView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = NotchEyeColorThemeRed;
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
            // Official Apple System Red
            return [NSColor colorWithDisplayP3Red:1.0 green:0.271 blue:0.227 alpha:1.0]; // #FF453A
        case NotchEyeColorThemeAmber:
            return [NSColor colorWithDisplayP3Red:1.0 green:0.624 blue:0.039 alpha:1.0]; // #FF9F0A
        case NotchEyeColorThemeCyan:
            return [NSColor colorWithDisplayP3Red:0.392 green:0.824 blue:1.0 alpha:1.0]; // #64D2FF
        case NotchEyeColorThemeGreen:
        default:
            // Official Apple System Green
            return [NSColor colorWithDisplayP3Red:0.196 green:0.843 blue:0.294 alpha:1.0]; // #32D74B
    }
}

- (void)setupSublayers {
    // 1. Background Shape Layer (Pitch black OLED cutout extension)
    _backgroundShapeLayer = [CAShapeLayer layer];
    _backgroundShapeLayer.fillColor = [NSColor colorWithWhite:0.0 alpha:0.98].CGColor;
    _backgroundShapeLayer.strokeColor = [NSColor colorWithWhite:1.0 alpha:0.12].CGColor;
    _backgroundShapeLayer.lineWidth = 0.5;
    _backgroundShapeLayer.opacity = 0.0;
    [self.layer addSublayer:_backgroundShapeLayer];

    // 2. Halo Stroke Layer (Continuous border around sides and bottom to top screen edge)
    _haloStrokeLayer = [CAShapeLayer layer];
    _haloStrokeLayer.fillColor = [NSColor clearColor].CGColor;
    _haloStrokeLayer.strokeColor = [self accentColor].CGColor;
    _haloStrokeLayer.lineWidth = 1.5;
    _haloStrokeLayer.lineCap = kCALineCapRound;
    _haloStrokeLayer.lineJoin = kCALineJoinRound;
    _haloStrokeLayer.opacity = 0.0;
    _haloStrokeLayer.shadowColor = [self accentColor].CGColor;
    _haloStrokeLayer.shadowRadius = 8.0;
    _haloStrokeLayer.shadowOpacity = 0.85;
    _haloStrokeLayer.shadowOffset = CGSizeMake(0, -1);
    [self.layer addSublayer:_haloStrokeLayer];

    // 3. Left: Circular Icon Badge (Apple Dynamic Island style)
    _iconBadgeLayer = [CALayer layer];
    _iconBadgeLayer.backgroundColor = [[self accentColor] colorWithAlphaComponent:0.16].CGColor;
    _iconBadgeLayer.cornerRadius = 14.0;
    _iconBadgeLayer.borderColor = [[self accentColor] colorWithAlphaComponent:0.35].CGColor;
    _iconBadgeLayer.borderWidth = 0.8;
    [self.layer addSublayer:_iconBadgeLayer];

    _iconLayer = [CALayer layer];
    _iconLayer.contentsGravity = kCAGravityResizeAspect;
    [_iconBadgeLayer addSublayer:_iconLayer];

    // 4. Status Dot + Pulse on the badge
    _statusDotLayer = [CALayer layer];
    _statusDotLayer.backgroundColor = [self accentColor].CGColor;
    _statusDotLayer.cornerRadius = 3.0;
    _statusDotLayer.shadowColor = [self accentColor].CGColor;
    _statusDotLayer.shadowRadius = 4.0;
    _statusDotLayer.shadowOpacity = 1.0;
    [_iconBadgeLayer addSublayer:_statusDotLayer];

    _statusDotPulseLayer = [CALayer layer];
    _statusDotPulseLayer.borderColor = [self accentColor].CGColor;
    _statusDotPulseLayer.borderWidth = 1.0;
    _statusDotPulseLayer.cornerRadius = 6.0;
    _statusDotPulseLayer.opacity = 0.0;
    [_iconBadgeLayer addSublayer:_statusDotPulseLayer];

    // 5. Title Text: SF Pro Display Semibold 12.5pt
    _titleLayer = [CATextLayer layer];
    _titleLayer.font = (__bridge CFTypeRef)[NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
    _titleLayer.fontSize = 12.5;
    _titleLayer.foregroundColor = [NSColor whiteColor].CGColor;
    _titleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _titleLayer.alignmentMode = kCAAlignmentLeft;
    [self.layer addSublayer:_titleLayer];

    // 6. Subtitle Text: SF Pro Text Regular 10.5pt (System secondary text)
    _subtitleLayer = [CATextLayer layer];
    _subtitleLayer.font = (__bridge CFTypeRef)[NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    _subtitleLayer.fontSize = 10.5;
    _subtitleLayer.foregroundColor = [NSColor colorWithWhite:0.65 alpha:1.0].CGColor;
    _subtitleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _subtitleLayer.alignmentMode = kCAAlignmentLeft;
    [self.layer addSublayer:_subtitleLayer];

    // 7. Right: Status Badge Capsule (Matching text and border colors!)
    _badgeContainer = [CALayer layer];
    _badgeContainer.cornerRadius = 7.0;
    _badgeContainer.borderWidth = 0.8;
    [self.layer addSublayer:_badgeContainer];

    _badgeTextLayer = [CATextLayer layer];
    _badgeTextLayer.font = (__bridge CFTypeRef)[NSFont systemFontOfSize:9.5 weight:NSFontWeightBold];
    _badgeTextLayer.fontSize = 9.5;
    _badgeTextLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _badgeTextLayer.alignmentMode = kCAAlignmentCenter;
    [_badgeContainer addSublayer:_badgeTextLayer];

    [self updateTheme:_theme];
}

- (void)updateIconImage {
    if (@available(macOS 11.0, *)) {
        NSString *symbolName = (_theme == NotchEyeColorThemeRed) ? @"video.slash.fill" : @"video.fill";
        NSImage *img = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
        if (!img) {
            img = [NSImage imageWithSystemSymbolName:@"video.fill" accessibilityDescription:nil];
        }
        if (img) {
            _iconLayer.contents = [self tintImage:img withColor:[self accentColor]];
        }
    }
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

/// Constructs a clean U-shape path anchored directly to the top edge of the screen (y = viewHeight).
/// @param rect The bounding rectangle of the island.
/// @param cornerRadius The radius of the bottom corners.
/// @param isClosed If YES, closes along the top edge for the solid fill. If NO, leaves top open for the glowing border stroke.
- (CGPathRef)newIslandPathForRect:(CGRect)rect cornerRadius:(CGFloat)radius isClosed:(BOOL)isClosed {
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat left = rect.origin.x;
    CGFloat right = rect.origin.x + rect.size.width;
    CGFloat bottom = rect.origin.y;
    CGFloat top = rect.origin.y + rect.size.height; // Exactly at top of window / screen!

    // Start at top-left screen edge
    CGPathMoveToPoint(path, NULL, left, top);
    // Down to bottom-left corner
    CGPathAddLineToPoint(path, NULL, left, bottom + radius);
    // Bottom-left curve
    CGPathAddArcToPoint(path, NULL, left, bottom, left + radius, bottom, radius);
    // Across bottom
    CGPathAddLineToPoint(path, NULL, right - radius, bottom);
    // Bottom-right curve
    CGPathAddArcToPoint(path, NULL, right, bottom, right, bottom + radius, radius);
    // Up to top-right screen edge
    CGPathAddLineToPoint(path, NULL, right, top);

    if (isClosed) {
        // Close across the top edge
        CGPathAddLineToPoint(path, NULL, left, top);
        CGPathCloseSubpath(path);
    }

    return path;
}

- (void)updateLayoutFramesForExpanded:(BOOL)expanded {
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height; // y = viewHeight is the top of the screen

    // Expanded: 320pt wide × 62pt tall (drops smoothly 30pt below physical 32pt notch)
    // Collapsed: 185pt wide × 32pt tall (matches physical notch exactly)
    CGFloat islandWidth = expanded ? 320.0 : 185.0;
    CGFloat islandHeight = expanded ? 62.0 : 32.0;
    CGFloat islandRadius = expanded ? 20.0 : 14.0;

    CGFloat islandX = (viewWidth - islandWidth) / 2.0;
    CGFloat islandY = viewHeight - islandHeight; // Bottom of the island
    CGRect islandRect = CGRectMake(islandX, islandY, islandWidth, islandHeight);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    // 1. Update background & stroke paths (both anchored to top screen edge y=viewHeight)
    CGPathRef fillPath = [self newIslandPathForRect:islandRect cornerRadius:islandRadius isClosed:YES];
    _backgroundShapeLayer.path = fillPath;
    CGPathRelease(fillPath);

    CGPathRef strokePath = [self newIslandPathForRect:islandRect cornerRadius:islandRadius isClosed:NO];
    _haloStrokeLayer.path = strokePath;
    CGPathRelease(strokePath);

    if (expanded) {
        // Vertical layout inside the dropdown portion:
        // The bottom portion extends from y = islandY (30pt below notch) to y = islandY + 30.
        CGFloat contentCenterY = islandY + 16.0;

        // Left Icon Badge (28x28 pt circle)
        CGFloat badgeSize = 28.0;
        CGFloat badgeX = islandX + 16.0;
        CGFloat badgeY = contentCenterY - (badgeSize / 2.0);
        _iconBadgeLayer.frame = CGRectMake(badgeX, badgeY, badgeSize, badgeSize);

        // Icon inside badge (14x14 pt)
        _iconLayer.frame = CGRectMake((badgeSize - 14.0) / 2.0, (badgeSize - 14.0) / 2.0, 14.0, 14.0);

        // Tiny status dot at top-right of badge
        _statusDotLayer.frame = CGRectMake(badgeSize - 7.0, badgeSize - 7.0, 6.0, 6.0);
        _statusDotPulseLayer.frame = CGRectMake(badgeSize - 10.0, badgeSize - 10.0, 12.0, 12.0);

        // Center Typography
        CGFloat textX = badgeX + badgeSize + 12.0;
        CGFloat textWidth = islandWidth - (badgeSize + 16.0 + 12.0) - 70.0;
        
        _titleLayer.frame = CGRectMake(textX, contentCenterY + 1.0, textWidth, 16.0);
        _subtitleLayer.frame = CGRectMake(textX, contentCenterY - 14.0, textWidth, 14.0);

        // Right Status Pill (Capsule badge)
        CGFloat pillW = (_theme == NotchEyeColorThemeRed) ? 52.0 : 44.0;
        CGFloat pillH = 20.0;
        CGFloat pillX = islandX + islandWidth - pillW - 16.0;
        CGFloat pillY = contentCenterY - (pillH / 2.0);
        _badgeContainer.frame = CGRectMake(pillX, pillY, pillW, pillH);
        _badgeTextLayer.frame = CGRectMake(0, 3.5, pillW, 14.0);

        // Opacity of content elements
        _iconBadgeLayer.opacity = 1.0;
        _titleLayer.opacity = 1.0;
        _subtitleLayer.opacity = 1.0;
        _badgeContainer.opacity = 1.0;
    } else {
        // Collapsed mode: only the glowing halo stroke remains
        _iconBadgeLayer.opacity = 0.0;
        _titleLayer.opacity = 0.0;
        _subtitleLayer.opacity = 0.0;
        _badgeContainer.opacity = 0.0;
    }

    [CATransaction commit];
}

#pragma mark - Public Presentation API

- (void)presentCameraActiveWithAppName:(NSString *)appName {
    _isCameraActive = YES;
    [_collapseTimer invalidate];
    _collapseTimer = nil;

    if (_theme == NotchEyeColorThemeRed) {
        _titleLayer.string = @"Citrix Camera Active";
        _subtitleLayer.string = @"Remote VM Redirection • Unmuted";
        _badgeTextLayer.string = @"ALERT";
    } else {
        _titleLayer.string = @"Camera Active";
        NSString *displayApp = (appName.length > 0) ? appName : @"FaceTime HD Camera";
        _subtitleLayer.string = [NSString stringWithFormat:@"%@ • Active", displayApp];
        _badgeTextLayer.string = @"LIVE";
    }

    [self updateTheme:_theme];

    _isExpanded = YES;
    _isHaloVisible = YES;

    // Fluid spring expansion animation
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.38];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    _backgroundShapeLayer.opacity = 1.0;
    _haloStrokeLayer.opacity = 1.0;
    [self updateLayoutFramesForExpanded:YES];

    [CATransaction commit];

    [self startPulseAnimation];

    // Retract to persistent notch halo after 3.8 seconds
    __weak typeof(self) weakSelf = self;
    _collapseTimer = [NSTimer scheduledTimerWithTimeInterval:3.8 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf collapseToHalo];
    }];
}

- (void)collapseToHalo {
    if (!_isCameraActive) return;
    _isExpanded = NO;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.35];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

    // Retract background, keep stroke glowing along notch bezel
    [self updateLayoutFramesForExpanded:NO];
    _backgroundShapeLayer.opacity = 0.0;
    _haloStrokeLayer.opacity = 1.0;

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
    _backgroundShapeLayer.opacity = 0.0;
    _haloStrokeLayer.opacity = 0.0;
    [self updateLayoutFramesForExpanded:NO];
    [CATransaction commit];

    [_statusDotLayer removeAllAnimations];
    [_statusDotPulseLayer removeAllAnimations];
}

- (void)startPulseAnimation {
    [_statusDotLayer removeAllAnimations];
    [_statusDotPulseLayer removeAllAnimations];

    // Smooth subtle breathing pulse on status dot
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @(1.0);
    pulse.toValue = @(1.3);
    pulse.duration = 0.8;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_statusDotLayer addAnimation:pulse forKey:@"dotPulse"];

    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @(0.8);
    ringScale.toValue = @(1.8);
    ringScale.duration = 1.6;
    ringScale.repeatCount = HUGE_VALF;

    CABasicAnimation *ringFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringFade.fromValue = @(0.8);
    ringFade.toValue = @(0.0);
    ringFade.duration = 1.6;
    ringFade.repeatCount = HUGE_VALF;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[ringScale, ringFade];
    group.duration = 1.6;
    group.repeatCount = HUGE_VALF;
    [_statusDotPulseLayer addAnimation:group forKey:@"ringPulse"];
}

- (void)updateTheme:(NotchEyeColorTheme)theme {
    _theme = theme;
    NSColor *color = [self accentColor];

    _haloStrokeLayer.strokeColor = color.CGColor;
    _haloStrokeLayer.shadowColor = color.CGColor;
    _iconBadgeLayer.backgroundColor = [color colorWithAlphaComponent:0.16].CGColor;
    _iconBadgeLayer.borderColor = [color colorWithAlphaComponent:0.35].CGColor;
    _statusDotLayer.backgroundColor = color.CGColor;
    _statusDotLayer.shadowColor = color.CGColor;
    _statusDotPulseLayer.borderColor = color.CGColor;

    // Badge styling: matching accent color on both background tint and text!
    _badgeContainer.backgroundColor = [color colorWithAlphaComponent:0.18].CGColor;
    _badgeContainer.borderColor = [color colorWithAlphaComponent:0.45].CGColor;
    _badgeTextLayer.foregroundColor = color.CGColor;

    [_badgeTextLayer setNeedsDisplay];
    [_titleLayer setNeedsDisplay];
    [_subtitleLayer setNeedsDisplay];

    [self updateIconImage];
}

@end
