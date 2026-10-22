#import <AppKit/AppKit.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc > 1) {
            if (strcmp(argv[1], "--test") == 0) {
                printf("🔔 Triggering NotchEye camera test alert...\n");
                [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"dev.notcheye.triggerTest"
                                                                              object:nil
                                                                            userInfo:nil
                                                                  deliverImmediately:YES];
                return 0;
            } else if (strcmp(argv[1], "--quit") == 0) {
                printf("🛑 Quitting NotchEye...\n");
                [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"dev.notcheye.quit"
                                                                              object:nil
                                                                            userInfo:nil
                                                                  deliverImmediately:YES];
                return 0;
            } else if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
                printf("NotchEye - Low-footprint Camera Activity Monitor for macOS Notch\n");
                printf("Usage:\n");
                printf("  open NotchEye.app        Launch as background menu bar utility\n");
                printf("  NotchEye --test          Trigger 5s camera test animation on running app\n");
                printf("  NotchEye --quit          Quit the running NotchEye instance\n");
                return 0;
            }
        }

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;

        [app run];
    }
    return 0;
}
