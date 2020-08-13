//
//  YMAnalyticsIntegration.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMIntegration.h"
#import "YMHTTPClient.h"
#import "YMStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const YMAnalyticsDidSendRequestNotification;
extern NSString *const YMAnalyticsRequestDidSucceedNotification;
extern NSString *const YMAnalyticsRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *const kYMUserIdFilename;
extern NSString *const kYMQueueFilename;
extern NSString *const kYMTraitsFilename;

NS_SWIFT_NAME(AnalyticsIntegration)
@interface YMAnalyticsIntegration : NSObject <YMIntegration>

- (id)initWithAnalytics:(YMAnalytics *)analytics httpClient:(YMHTTPClient *)httpClient fileStorage:(id<YMStorage>)fileStorage userDefaultsStorage:(id<YMStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
