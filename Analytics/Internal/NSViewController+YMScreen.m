//
//  NSViewController+YMScreen.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "NSViewController+YMScreen.h"
#import <objc/runtime.h>
#import "YMAnalytics.h"
#import "YMAnalyticsUtils.h"
#import "YMScreenReporting.h"
#import "YMUtils.h"


#if TARGET_OS_OSX
@implementation NSViewController (YMScreen)

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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

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

+ (NSViewController *)ym_rootViewControllerFromView:(NSView *)view
{
    NSViewController *rootViewController = view.window.contentViewController;
    
    if (rootViewController.childViewControllers.count > 0) {
        if ([rootViewController conformsToProtocol:@protocol(YMScreenReporting)] && [rootViewController respondsToSelector:@selector(ym_mainViewController)]) {
            __auto_type screenReporting = (NSViewController<YMScreenReporting>*)rootViewController;
            return screenReporting.ym_mainViewController;
        }

        // fall back on first child UIViewController as a "best guess" assumption
        __auto_type *firstChildViewController = rootViewController.childViewControllers.firstObject;
        if (firstChildViewController != nil) {
            return firstChildViewController;
        }
    }

    return rootViewController;
}

- (void)ym_viewDidAppear:(BOOL)animated
{
    NSViewController *top = [[self class] ym_rootViewControllerFromView:self.view];
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
        __auto_type screenReporting = (NSViewController<YMScreenReporting>*)top;
        [screenReporting ym_trackScreen:top name:name];
        return;
    }

    [[YMAnalytics sharedAnalytics] screen:name properties:nil options:nil];

    [self ym_viewDidAppear:animated];
}

- (void)ym_viewDidDisappear:(BOOL)animated
{
    NSViewController *top = [[self class] ym_rootViewControllerFromView:self.view];
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
