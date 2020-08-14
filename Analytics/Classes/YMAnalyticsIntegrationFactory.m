//
//  YMAnalyticsIntegrationFactory.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMAnalyticsIntegrationFactory.h"
#import "YMAnalyticsIntegration.h"

@implementation YMAnalyticsIntegrationFactory

- (id)initWithHTTPClient:(YMHTTPClient *)client fileStorage:(id<YMStorage>)fileStorage userDefaultsStorage:(id<YMStorage>)userDefaultsStorage
{
    if (self = [super init]) {
        _client = client;
        _userDefaultsStorage = userDefaultsStorage;
        _fileStorage = fileStorage;
    }
    return self;
}

- (id<YMIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(YMAnalytics *)analytics
{
    return [[YMAnalyticsIntegration alloc] initWithAnalytics:analytics httpClient:self.client fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage];
}

- (NSString *)key
{
    return @"YuktaOne.io";
}

@end
