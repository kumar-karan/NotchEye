#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

- (void)triggerTestAlert:(nullable id)sender;
- (void)triggerTestAlertRuby:(nullable id)sender;
- (void)triggerTestAlertGreen:(nullable id)sender;
- (void)quitApp:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
