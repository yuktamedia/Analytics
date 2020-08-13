//
//  YMAnalyticsIntegrationFactory.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMIntegrationFactory.h"
#import "YMHTTPClient.h"
#import "YMStorage.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AnalyticsIntegrationFactory)
@interface YMAnalyticsIntegrationFactory : NSObject

@property (nonatomic, strong) YMHTTPClient *client;
@property (nonatomic, strong) id<YMStorage> userDefaultsStorage;
@property (nonatomic, strong) id<YMStorage> fileStorage;

- (instancetype)initWithHTTPClient:(YMHTTPClient *)client fileStorage:(id<YMStorage>)fileStorage userDefaultsStorage:(id<YMStorage>)userDefaultsStorage;


@end

NS_ASSUME_NONNULL_END
