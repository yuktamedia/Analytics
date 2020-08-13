//
//  YMState.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YMAnalyticsConfiguration;

@interface YMUserInfo: NSObject
@property (nonatomic, strong) NSString *anonymousId;
@property (nonatomic, strong, nullable) NSString *userId;
@property (nonatomic, strong, nullable) NSDictionary *traits;
@end

@interface YMPayloadContext: NSObject
@property (nonatomic, readonly) NSDictionary *payload;
@property (nonatomic, strong, nullable) NSDictionary *referrer;
@property (nonatomic, strong, nullable) NSString *deviceToken;

- (void)updateStaticContext;

@end



@interface YMState : NSObject

@property (nonatomic, readonly) YMUserInfo *userInfo;
@property (nonatomic, readonly) YMPayloadContext *context;

@property (nonatomic, strong, nullable) YMAnalyticsConfiguration *configuration;

+ (instancetype)sharedInstance;
- (instancetype)init __unavailable;

- (void)setUserInfo:(YMUserInfo *)userInfo;
@end

NS_ASSUME_NONNULL_END
