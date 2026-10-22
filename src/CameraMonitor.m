#import "CameraMonitor.h"
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMediaIO/CMIOHardware.h>

@interface CameraMonitor () {
    NSMutableArray<NSNumber *> *_monitoredDeviceIDs;
    dispatch_queue_t _monitorQueue;
    NSTimeInterval _lastEventTimestamp;
    BOOL _lastKnownState;
}
@end

@implementation CameraMonitor

- (instancetype)initWithCallback:(CameraStateChangeCallback)callback {
    self = [super init];
    if (self) {
        _callback = [callback copy];
        _monitoredDeviceIDs = [NSMutableArray array];
        _monitorQueue = dispatch_queue_create("dev.notcheye.camera-monitor", DISPATCH_QUEUE_SERIAL);
        _lastEventTimestamp = 0;
        _lastKnownState = NO;
        _isRunning = NO;
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

- (void)startMonitoring {
    if (_isRunning) return;
    _isRunning = YES;

    [self enableDALAccess];

    [self updateMonitoredDevices];

    // Listen for hardware connections/disconnections
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceListChanged:)
                                                 name:AVCaptureDeviceWasConnectedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceListChanged:)
                                                 name:AVCaptureDeviceWasDisconnectedNotification
                                               object:nil];

    // Check initial state
    BOOL initialActive = [self isAnyCameraActive];
    _lastKnownState = initialActive;
    if (initialActive && self.callback) {
        NSString *app = [self detectActiveCameraApplication];
        self.callback(YES, app);
    }
}

- (void)stopMonitoring {
    if (!_isRunning) return;
    _isRunning = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    for (NSNumber *devNum in _monitoredDeviceIDs) {
        CMIOObjectID deviceID = [devNum unsignedIntValue];
        [self removeListenerFromDevice:deviceID];
    }
    [_monitoredDeviceIDs removeAllObjects];
}

- (BOOL)isCameraActive {
    return _lastKnownState;
}

#pragma mark - CoreMediaIO DAL Access

- (void)enableDALAccess {
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyAllowScreenCaptureDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };
    UInt32 allow = 1;
    UInt32 size = sizeof(allow);
    CMIOObjectSetPropertyData(kCMIOObjectSystemObject, &prop, 0, NULL, size, &allow);
}

#pragma mark - Device Discovery & Listeners

- (NSArray<NSNumber *> *)discoverVideoDevices {
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };
    UInt32 dataSize = 0;
    OSStatus status = CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject, &prop, 0, NULL, &dataSize);
    if (status != noErr || dataSize == 0) return @[];

    int count = dataSize / sizeof(CMIOObjectID);
    CMIOObjectID *devices = malloc(dataSize);
    status = CMIOObjectGetPropertyData(kCMIOObjectSystemObject, &prop, 0, NULL, dataSize, &dataSize, devices);
    if (status != noErr) {
        free(devices);
        return @[];
    }

    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        CMIOObjectID devID = devices[i];
        if ([self isVideoDevice:devID]) {
            [result addObject:@(devID)];
        }
    }
    free(devices);
    return result;
}

- (BOOL)isVideoDevice:(CMIOObjectID)deviceID {
    CMIOObjectPropertyAddress prop = {
        kCMIODevicePropertyStreams,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };
    UInt32 dataSize = 0;
    OSStatus status = CMIOObjectGetPropertyDataSize(deviceID, &prop, 0, NULL, &dataSize);
    return (status == noErr && dataSize > 0);
}

- (void)updateMonitoredDevices {
    for (NSNumber *devNum in _monitoredDeviceIDs) {
        [self removeListenerFromDevice:[devNum unsignedIntValue]];
    }
    [_monitoredDeviceIDs removeAllObjects];

    NSArray<NSNumber *> *devices = [self discoverVideoDevices];
    for (NSNumber *devNum in devices) {
        CMIOObjectID devID = [devNum unsignedIntValue];
        [self attachListenerToDevice:devID];
        [_monitoredDeviceIDs addObject:devNum];
    }
}

- (void)attachListenerToDevice:(CMIOObjectID)deviceID {
    CMIOObjectPropertyAddress prop = {
        kCMIODevicePropertyDeviceIsRunningSomewhere,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };

    __weak typeof(self) weakSelf = self;
    OSStatus status = CMIOObjectAddPropertyListenerBlock(
        deviceID,
        &prop,
        _monitorQueue,
        ^(UInt32 inNumberAddresses, const CMIOObjectPropertyAddress addresses[]) {
            [weakSelf handleStateChangeNotification];
        }
    );

    if (status != noErr) {
        NSLog(@"[NotchEye] Could not attach listener to device %u: %d", deviceID, status);
    }
}

- (void)removeListenerFromDevice:(CMIOObjectID)deviceID {
    CMIOObjectPropertyAddress prop = {
        kCMIODevicePropertyDeviceIsRunningSomewhere,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };
    CMIOObjectRemovePropertyListenerBlock(deviceID, &prop, _monitorQueue, ^(UInt32 inNumberAddresses, const CMIOObjectPropertyAddress addresses[]) {});
}

#pragma mark - State Change Handling

- (void)handleStateChangeNotification {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastEventTimestamp < 0.3) {
        return; // debounce rapid triggers
    }
    _lastEventTimestamp = now;

    // Small delay to allow macOS camera state to settle
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), _monitorQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isRunning) return;

        BOOL isActive = [strongSelf isAnyCameraActive];
        if (isActive == strongSelf->_lastKnownState) return;

        strongSelf->_lastKnownState = isActive;
        NSString *appName = isActive ? [strongSelf detectActiveCameraApplication] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (strongSelf.callback) {
                strongSelf.callback(isActive, appName);
            }
        });
    });
}

- (BOOL)isAnyCameraActive {
    NSArray<NSNumber *> *devices = [self discoverVideoDevices];
    for (NSNumber *devNum in devices) {
        if ([self isDeviceRunning:[devNum unsignedIntValue]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isDeviceRunning:(CMIOObjectID)deviceID {
    CMIOObjectPropertyAddress prop = {
        kCMIODevicePropertyDeviceIsRunningSomewhere,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMain
    };
    UInt32 isRunning = 0;
    UInt32 dataSize = sizeof(isRunning);
    OSStatus status = CMIOObjectGetPropertyData(deviceID, &prop, 0, NULL, dataSize, &dataSize, &isRunning);
    return (status == noErr && isRunning != 0);
}

- (NSString *)detectActiveCameraApplication {
    // 1. Check if Citrix is running or active (user's primary VM environment)
    NSArray<NSRunningApplication *> *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];

    // Priority 1: If Citrix Viewer is active or frontmost
    for (NSRunningApplication *app in runningApps) {
        NSString *name = app.localizedName;
        NSString *bundleId = app.bundleIdentifier;
        if ([name containsString:@"Citrix Viewer"] || [bundleId containsString:@"icaviewer"]) {
            return @"Citrix Viewer";
        }
    }

    // Priority 2: Check other common video apps
    NSArray<NSString *> *videoApps = @[
        @"Citrix", @"Zoom", @"Microsoft Teams", @"FaceTime", @"Google Chrome",
        @"Slack", @"Webex", @"Photo Booth", @"QuickTime Player", @"OBS"
    ];

    if (frontApp) {
        for (NSString *candidate in videoApps) {
            if ([frontApp.localizedName localizedCaseInsensitiveContainsString:candidate]) {
                return frontApp.localizedName;
            }
        }
    }

    for (NSRunningApplication *app in runningApps) {
        if (app.isActive) {
            for (NSString *candidate in videoApps) {
                if ([app.localizedName localizedCaseInsensitiveContainsString:candidate]) {
                    return app.localizedName;
                }
            }
        }
    }

    // Fallback: Return frontmost app or generic
    if (frontApp && frontApp.localizedName.length > 0) {
        return frontApp.localizedName;
    }

    return @"Active Session";
}

- (void)deviceListChanged:(NSNotification *)note {
    dispatch_async(_monitorQueue, ^{
        [self updateMonitoredDevices];
    });
}

@end
