#import "UIViewController+YMScreen.h"
#import <objc/runtime.h>
#import "YMAnalytics.h"
#import "YMAnalyticsUtils.h"
#import "YMScreenReporting.h"
#import "YMUtils.h"

#if TARGET_OS_IPHONE
@implementation UIViewController (YMScreen)

NSDate *activityLoadTime;
NSDate *activityUnloadTime;

+ (void)ym_swizzleViewDidAppear
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(ym_viewDidAppear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class,
                            originalSelector,
                            method_getImplementation(swizzledMethod),
                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

+ (void)ym_swizzleViewDidDisappear
{
    static dispatch_once_t oncedisToken;
    dispatch_once(&oncedisToken, ^{
        Class class = [self class];
        
        NSLog(@"in ui view did disappear method to attach event");

        SEL originalSelector = @selector(viewDidDisappear:);
        SEL swizzledSelector = @selector(ym_viewDidDisappear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class,
                            originalSelector,
                            method_getImplementation(swizzledMethod),
                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


+ (UIViewController *)ym_rootViewControllerFromView:(UIView *)view
{
    UIViewController *root = view.window.rootViewController;
    return [self ym_topViewController:root];
}

+ (UIViewController *)ym_topViewController:(UIViewController *)rootViewController
{
    UIViewController *nextRootViewController = [self ym_nextRootViewController:rootViewController];
    if (nextRootViewController) {
        return [self ym_topViewController:nextRootViewController];
    }

    return rootViewController;
}

+ (UIViewController *)ym_nextRootViewController:(UIViewController *)rootViewController
{
    UIViewController *presentedViewController = rootViewController.presentedViewController;
    if (presentedViewController != nil) {
        return presentedViewController;
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *lastViewController = ((UINavigationController *)rootViewController).viewControllers.lastObject;
        return lastViewController;
    }

    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        __auto_type *currentTabViewController = ((UITabBarController*)rootViewController).selectedViewController;
        if (currentTabViewController != nil) {
            return currentTabViewController;
        }
    }

    if (rootViewController.childViewControllers.count > 0) {
        if ([rootViewController conformsToProtocol:@protocol(YMScreenReporting)] && [rootViewController respondsToSelector:@selector(ym_mainViewController)]) {
            __auto_type screenReporting = (UIViewController<YMScreenReporting>*)rootViewController;
            return screenReporting.ym_mainViewController;
        }

        // fall back on first child UIViewController as a "best guess" assumption
        __auto_type *firstChildViewController = rootViewController.childViewControllers.firstObject;
        if (firstChildViewController != nil) {
            return firstChildViewController;
        }
    }

    return nil;
}

- (void)ym_viewDidAppear:(BOOL)animated
{
    UIViewController *top = [[self class] ym_rootViewControllerFromView:self.view];
    if (!top) {
        YMLog(@"Could not infer screen.");
        return;
    }

    NSString *name = [[[top class] description] stringByReplacingOccurrencesOfString:@"ViewController" withString:@""];
    
    if (!name || name.length == 0) {
        // if no class description found, try view controller's title.
        name = [top title];
        // Class name could be just "ViewController".
        if (name.length == 0) {
            YMLog(@"Could not infer screen name.");
            name = @"Unknown";
        }
    }

    activityLoadTime = [NSDate date];
    
    [[YMAnalytics sharedAnalytics] track:@"Activity Started" properties:@{
        @"loadTime" : iso8601FormattedString(activityLoadTime),
        @"activityName" : name
    }];

    if ([top conformsToProtocol:@protocol(YMScreenReporting)] && [top respondsToSelector:@selector(ym_trackScreen:name:)]) {
        __auto_type screenReporting = (UIViewController<YMScreenReporting>*)top;
        [screenReporting ym_trackScreen:top name:name];
        return;
    }

    [[YMAnalytics sharedAnalytics] screen:name properties:nil options:nil];

    [self ym_viewDidAppear:animated];
}

- (void)ym_viewDidDisappear:(BOOL)animated
{
    NSLog(@"in ui view did disappear method to fire event");
    UIViewController *top = [[self class] ym_rootViewControllerFromView:self.view];
    if (!top) {
        YMLog(@"Could not infer screen.");
        return;
    }

    NSString *name = [[[top class] description] stringByReplacingOccurrencesOfString:@"ViewController" withString:@""];
    
    if (!name || name.length == 0) {
        // if no class description found, try view controller's title.
        name = [top title];
        // Class name could be just "ViewController".
        if (name.length == 0) {
            YMLog(@"Could not infer screen name.");
            name = @"Unknown";
        }
    }

    activityUnloadTime = [NSDate date];
    
    [[YMAnalytics sharedAnalytics] track:@"Activity Stopped" properties:@{
        @"loadTime" : iso8601FormattedString(activityLoadTime),
        @"unLoadTime" : iso8601FormattedString(activityUnloadTime),
        @"activityName" : name
    }];

    [self ym_viewDidDisappear:animated];
}

@end
#endif
