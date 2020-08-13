//
//  YMContext.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMIntegration.h"

typedef NS_ENUM(NSInteger, YMEventType) {
    // Should not happen, but default state
    YMEventTypeUndefined,
    // Core Tracking Methods
    YMEventTypeIdentify,
    YMEventTypeTrack,
    YMEventTypeScreen,
    YMEventTypeGroup,
    YMEventTypeAlias,

    // General utility
    YMEventTypeReset,
    YMEventTypeFlush,

    // Remote Notification
    YMEventTypeReceivedRemoteNotification,
    YMEventTypeFailedToRegisterForRemoteNotifications,
    YMEventTypeRegisteredForRemoteNotifications,
    YMEventTypeHandleActionWithForRemoteNotification,

    // Application Lifecycle
    YMEventTypeApplicationLifecycle,
    //    DidFinishLaunching,
    //    YMEventTypeApplicationDidEnterBackground,
    //    YMEventTypeApplicationWillEnterForeground,
    //    YMEventTypeApplicationWillTerminate,
    //    YMEventTypeApplicationWillResignActive,
    //    YMEventTypeApplicationDidBecomeActive,

    // Misc.
    YMEventTypeContinueUserActivity,
    YMEventTypeOpenURL,

} NS_SWIFT_NAME(EventType);

@class YMAnalytics;
@protocol YMMutableContext;


NS_SWIFT_NAME(Context)
@interface YMContext : NSObject <NSCopying>

// Loopback reference to the top level YMAnalytics object.
// Not sure if it's a good idea to keep this around in the context.
// since we don't really want people to use it due to the circular
// reference and logic (Thus prefixing with underscore). But
// Right now it is required for integrations to work so I guess we'll leave it in.
@property (nonatomic, readonly, nonnull) YMAnalytics *_analytics;
@property (nonatomic, readonly) YMEventType eventType;

@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) YMPayload *payload;
@property (nonatomic, readonly) BOOL debug;

- (instancetype _Nonnull)initWithAnalytics:(YMAnalytics *_Nonnull)analytics;

- (YMContext *_Nonnull)modify:(void (^_Nonnull)(id<YMMutableContext> _Nonnull ctx))modify;

@end

@protocol YMMutableContext <NSObject>

@property (nonatomic) YMEventType eventType;
@property (nonatomic, nullable) YMPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end
