//
//  YMPayload.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Payload)
@interface YMPayload : NSObject

@property (nonatomic, readonly) JSON_DICT context;
@property (nonatomic, readonly) JSON_DICT integrations;
@property (nonatomic, readonly) NSString *channel;
@property (nonatomic, strong) NSString *timestamp;
@property (nonatomic, strong) NSString *messageId;
@property (nonatomic, strong) NSString *anonymousId;
@property (nonatomic, strong) NSString *userId;

- (instancetype)initWithContext:(JSON_DICT)context integrations:(JSON_DICT)integrations;

@end


NS_SWIFT_NAME(ApplicationLifecyclePayload)
@interface YMApplicationLifecyclePayload : YMPayload

@property (nonatomic, strong) NSString *notificationName;

// ApplicationDidFinishLaunching only
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

@end


NS_SWIFT_NAME(ContinueUserActivityPayload)
@interface YMContinueUserActivityPayload : YMPayload

@property (nonatomic, strong) NSUserActivity *activity;

@end

NS_SWIFT_NAME(OpenURLPayload)
@interface YMOpenURLPayload : YMPayload

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END


NS_SWIFT_NAME(RemoteNotificationPayload)
@interface YMRemoteNotificationPayload : YMPayload

// YMEventTypeHandleActionWithForRemoteNotification
@property (nonatomic, strong, nullable) NSString *actionIdentifier;

// YMEventTypeHandleActionWithForRemoteNotification
// YMEventTypeReceivedRemoteNotification
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

// YMEventTypeFailedToRegisterForRemoteNotifications
@property (nonatomic, strong, nullable) NSError *error;

// YMEventTypeRegisteredForRemoteNotifications
@property (nonatomic, strong, nullable) NSData *deviceToken;

@end
