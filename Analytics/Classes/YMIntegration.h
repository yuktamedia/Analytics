//
//  YMIntegration.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMIdentifyPayload.h"
#import "YMTrackPayload.h"
#import "YMScreenPayload.h"
#import "YMAliasPayload.h"
#import "YMIdentifyPayload.h"
#import "YMGroupPayload.h"
#import "YMContext.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Integration)
@protocol YMIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[YMAnalytics sharedInstance] identify:someUserId];
// 2. [[YMAnalytics sharedInstance] identify:someUserId traits:someTraits];
// 3. [[YMAnalytics sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(YMIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[YMAnalytics sharedInstance] track:someEvent];
// 2. [[YMAnalytics sharedInstance] track:someEvent properties:someProperties];
// 3. [[YMAnalytics sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(YMTrackPayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[YMAnalytics sharedInstance] screen:someEvent];
// 2. [[YMAnalytics sharedInstance] screen:someEvent properties:someProperties];
// 3. [[YMAnalytics sharedInstance] screen:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/screen/
- (void)screen:(YMScreenPayload *)payload;

// Group will be called when the user calls either of the following:
// 1. [[YMAnalytics sharedInstance] group:someGroupId];
// 2. [[YMAnalytics sharedInstance] group:someGroupId traits:];
// 3. [[YMAnalytics sharedInstance] group:someGroupId traits:someGroupTraits options:someOptions];
// @see https://segment.com/docs/spec/group/
- (void)group:(YMGroupPayload *)payload;

// Alias will be called when the user calls either of the following:
// 1. [[YMAnalytics sharedInstance] alias:someNewId];
// 2. [[YMAnalytics sharedInstance] alias:someNewId options:someOptions];
// @see https://segment.com/docs/spec/alias/
- (void)alias:(YMAliasPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// App Delegate Callbacks

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
