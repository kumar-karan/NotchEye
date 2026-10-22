#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CameraStateChangeCallback)(BOOL isActive, NSString * _Nullable appName);

@interface CameraMonitor : NSObject

@property (nonatomic, copy, readonly) CameraStateChangeCallback callback;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) BOOL isCameraActive;

- (instancetype)initWithCallback:(CameraStateChangeCallback)callback;
- (void)startMonitoring;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END
