#import "AppDelegate.h"
#import "CameraMonitor.h"
#import "NotchOverlayWindow.h"
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate () <UNUserNotificationCenterDelegate> {
    NSStatusItem *_statusItem;
    CameraMonitor *_cameraMonitor;
    NotchOverlayWindow *_overlayWindow;
    BOOL _soundEnabled;
    BOOL _bannerEnabled;
    BOOL _autoTheme;
    NotchEyeColorTheme _currentTheme;
    NSMenuItem *_statusMenuItem;
}
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _soundEnabled = YES;
    _bannerEnabled = YES;
    _autoTheme = YES; // Auto-select Ruby Red for Citrix/VM, Laser Green for native apps
    _currentTheme = NotchEyeColorThemeGreen;

    [self setupNotificationCenter];
    [self setupMenuBar];
    [self setupOverlayWindow];
    [self setupCameraMonitoring];
    [self setupDistributedNotifications];

    NSLog(@"[NotchEye] Initialized successfully. Watching CoreMediaIO camera events.");
}

- (void)setupDistributedNotifications {
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(triggerTestAlert:)
                                                            name:@"dev.notcheye.triggerTest"
                                                          object:nil];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(quitApp:)
                                                            name:@"dev.notcheye.quit"
                                                          object:nil];
}

- (void)setupNotificationCenter {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[NotchEye] Notification authorization error: %@", error);
        }
    }];
}

- (void)setupOverlayWindow {
    _overlayWindow = [[NotchOverlayWindow alloc] initOverlay];
    [_overlayWindow setTheme:_currentTheme];
}

- (void)setupMenuBar {
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    if (_statusItem.button) {
        NSImage *icon = nil;
        if (@available(macOS 11.0, *)) {
            icon = [NSImage imageWithSystemSymbolName:@"camera.badge.ellipsis" accessibilityDescription:@"NotchEye"];
            if (!icon) {
                icon = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"NotchEye"];
            }
        }
        if (icon) {
            [icon setTemplate:YES];
            _statusItem.button.image = icon;
        } else {
            _statusItem.button.title = @"👁️";
        }
    }

    [self buildMenu];
}

- (void)buildMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"NotchEye"];

    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"NotchEye • Camera Monitor" action:nil keyEquivalent:@""];
    titleItem.enabled = NO;
    [menu addItem:titleItem];

    [menu addItem:[NSMenuItem separatorItem]];

    _statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"Camera: Inactive" action:nil keyEquivalent:@""];
    _statusMenuItem.enabled = NO;
    [menu addItem:_statusMenuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Test Alert
    NSMenuItem *testItem = [[NSMenuItem alloc] initWithTitle:@"Test Alert (Ruby Red / Citrix)" action:@selector(triggerTestAlertRuby:) keyEquivalent:@"t"];
    testItem.target = self;
    [menu addItem:testItem];

    NSMenuItem *testGreenItem = [[NSMenuItem alloc] initWithTitle:@"Test Alert (Laser Green / Normal)" action:@selector(triggerTestAlertGreen:) keyEquivalent:@"g"];
    testGreenItem.target = self;
    [menu addItem:testGreenItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Sound toggle
    NSMenuItem *soundItem = [[NSMenuItem alloc] initWithTitle:@"Play Alert Chime" action:@selector(toggleSound:) keyEquivalent:@"s"];
    soundItem.target = self;
    soundItem.state = _soundEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:soundItem];

    // Banner toggle
    NSMenuItem *bannerItem = [[NSMenuItem alloc] initWithTitle:@"Show System Banner" action:@selector(toggleBanner:) keyEquivalent:@"b"];
    bannerItem.target = self;
    bannerItem.state = _bannerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:bannerItem];

    // Theme Submenu
    NSMenuItem *themeItem = [[NSMenuItem alloc] initWithTitle:@"Color Scheme" action:nil keyEquivalent:@""];
    NSMenu *themeSubmenu = [[NSMenu alloc] initWithTitle:@"Color Scheme"];

    NSMenuItem *autoItem = [[NSMenuItem alloc] initWithTitle:@"Smart Auto (Ruby for Citrix, Green for Mac)" action:@selector(selectThemeAuto:) keyEquivalent:@""];
    autoItem.target = self;
    autoItem.state = _autoTheme ? NSControlStateValueOn : NSControlStateValueOff;
    [themeSubmenu addItem:autoItem];

    [themeSubmenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *greenItem = [[NSMenuItem alloc] initWithTitle:@"Laser Green (#30D158)" action:@selector(selectThemeGreen:) keyEquivalent:@""];
    greenItem.target = self;
    greenItem.state = (!_autoTheme && _currentTheme == NotchEyeColorThemeGreen) ? NSControlStateValueOn : NSControlStateValueOff;
    [themeSubmenu addItem:greenItem];

    NSMenuItem *redItem = [[NSMenuItem alloc] initWithTitle:@"Alert Ruby Red (#FF3B30)" action:@selector(selectThemeRed:) keyEquivalent:@""];
    redItem.target = self;
    redItem.state = (!_autoTheme && _currentTheme == NotchEyeColorThemeRed) ? NSControlStateValueOn : NSControlStateValueOff;
    [themeSubmenu addItem:redItem];

    NSMenuItem *amberItem = [[NSMenuItem alloc] initWithTitle:@"Privacy Amber (#FF9E0A)" action:@selector(selectThemeAmber:) keyEquivalent:@""];
    amberItem.target = self;
    amberItem.state = (!_autoTheme && _currentTheme == NotchEyeColorThemeAmber) ? NSControlStateValueOn : NSControlStateValueOff;
    [themeSubmenu addItem:amberItem];

    NSMenuItem *cyanItem = [[NSMenuItem alloc] initWithTitle:@"CAD Cyan (#38BDF8)" action:@selector(selectThemeCyan:) keyEquivalent:@""];
    cyanItem.target = self;
    cyanItem.state = (!_autoTheme && _currentTheme == NotchEyeColorThemeCyan) ? NSControlStateValueOn : NSControlStateValueOff;
    [themeSubmenu addItem:cyanItem];

    themeItem.submenu = themeSubmenu;
    [menu addItem:themeItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit NotchEye" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    _statusItem.menu = menu;
}

- (void)setupCameraMonitoring {
    __weak typeof(self) weakSelf = self;
    _cameraMonitor = [[CameraMonitor alloc] initWithCallback:^(BOOL isActive, NSString * _Nullable appName) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleCameraStateChange:isActive appName:appName];
        });
    }];
    [_cameraMonitor startMonitoring];
}

- (void)handleCameraStateChange:(BOOL)isActive appName:(NSString *)appName {
    if (isActive) {
        NSString *displayApp = appName.length > 0 ? appName : @"Citrix HDX Pipe";
        
        // Smart theme selection: if Citrix or VDI is active, use Alert Ruby Red (#FF3B30)
        BOOL isVDI = [displayApp containsString:@"Citrix"] || [displayApp containsString:@"VMware"] || [displayApp containsString:@"Remote"];
        if (_autoTheme) {
            _currentTheme = isVDI ? NotchEyeColorThemeRed : NotchEyeColorThemeGreen;
            [_overlayWindow setTheme:_currentTheme];
        }

        NSString *dot = (_currentTheme == NotchEyeColorThemeRed) ? @"🔴" : @"🟢";
        _statusMenuItem.title = [NSString stringWithFormat:@"Camera: %@ Active (%@)", dot, displayApp];

        if (@available(macOS 11.0, *)) {
            _statusItem.button.contentTintColor = (_currentTheme == NotchEyeColorThemeRed) ? [NSColor systemRedColor] : [NSColor systemGreenColor];
        }

        [_overlayWindow showCameraActiveWithAppName:displayApp];

        if (_soundEnabled) {
            [[NSSound soundNamed:@"Tink"] play];
        }

        if (_bannerEnabled) {
            [self dispatchBannerNotificationWithAppName:displayApp isAlert:isVDI];
        }
    } else {
        _statusMenuItem.title = @"Camera: Inactive";

        if (@available(macOS 11.0, *)) {
            _statusItem.button.contentTintColor = nil;
        }

        [_overlayWindow hideCameraActive];
    }
}

- (void)dispatchBannerNotificationWithAppName:(NSString *)appName isAlert:(BOOL)isAlert {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = isAlert ? @"🚨 Citrix Camera Redirect Active" : @"📷 Camera In Use";
    content.body = [NSString stringWithFormat:@"Hardware video streaming captured by %@", appName];
    content.sound = nil; // Handled by AppKit NSSound

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                        content:content
                                                                        trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

#pragma mark - Actions

- (void)triggerTestAlert:(id)sender {
    [self triggerTestAlertRuby:sender];
}

- (void)triggerTestAlertRuby:(id)sender {
    NSLog(@"[NotchEye] Test alert Ruby Red triggered");
    _currentTheme = NotchEyeColorThemeRed;
    [_overlayWindow setTheme:_currentTheme];
    [self handleCameraStateChange:YES appName:@"Citrix HDX Pipe"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_cameraMonitor.isCameraActive) {
            [self handleCameraStateChange:NO appName:nil];
        }
    });
}

- (void)triggerTestAlertGreen:(id)sender {
    NSLog(@"[NotchEye] Test alert Laser Green triggered");
    _currentTheme = NotchEyeColorThemeGreen;
    [_overlayWindow setTheme:_currentTheme];
    [self handleCameraStateChange:YES appName:@"FaceTime HD • Native"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_cameraMonitor.isCameraActive) {
            [self handleCameraStateChange:NO appName:nil];
        }
    });
}

- (void)toggleSound:(NSMenuItem *)sender {
    _soundEnabled = !_soundEnabled;
    sender.state = _soundEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)toggleBanner:(NSMenuItem *)sender {
    _bannerEnabled = !_bannerEnabled;
    sender.state = _bannerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)selectThemeAuto:(id)sender {
    _autoTheme = YES;
    [self buildMenu];
}

- (void)selectThemeGreen:(id)sender {
    _autoTheme = NO;
    _currentTheme = NotchEyeColorThemeGreen;
    [_overlayWindow setTheme:_currentTheme];
    [self buildMenu];
}

- (void)selectThemeRed:(id)sender {
    _autoTheme = NO;
    _currentTheme = NotchEyeColorThemeRed;
    [_overlayWindow setTheme:_currentTheme];
    [self buildMenu];
}

- (void)selectThemeAmber:(id)sender {
    _autoTheme = NO;
    _currentTheme = NotchEyeColorThemeAmber;
    [_overlayWindow setTheme:_currentTheme];
    [self buildMenu];
}

- (void)selectThemeCyan:(id)sender {
    _autoTheme = NO;
    _currentTheme = NotchEyeColorThemeCyan;
    [_overlayWindow setTheme:_currentTheme];
    [self buildMenu];
}

- (void)quitApp:(id)sender {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [_cameraMonitor stopMonitoring];
    [_overlayWindow close];
    [NSApp terminate:nil];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

@end
