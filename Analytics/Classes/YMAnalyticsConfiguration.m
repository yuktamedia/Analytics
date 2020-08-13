//
//  YMAnalyticsConfiguration.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMAnalyticsConfiguration.h"
#import "YMAnalytics.h"
#import "YMCrypto.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#if TARGET_OS_IPHONE
@implementation UIApplication (YMApplicationProtocol)

- (UIBackgroundTaskIdentifier)ym_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler
{
    return [self beginBackgroundTaskWithName:taskName expirationHandler:handler];
}

- (void)ym_endBackgroundTask:(UIBackgroundTaskIdentifier)identifier
{
    [self endBackgroundTask:identifier];
}

@end
#endif

@implementation YMAnalyticsExperimental
@end

@interface YMAnalyticsConfiguration ()

@property (nonatomic, copy, readwrite) NSString *writeKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;
@property (nonatomic, strong) YMAnalyticsExperimental *experimental;

@end


@implementation YMAnalyticsConfiguration

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey
{
    return [[YMAnalyticsConfiguration alloc] initWithWriteKey:writeKey];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey
{
    if (self = [self init]) {
        self.writeKey = writeKey;
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.experimental = [[YMAnalyticsExperimental alloc] init];
        self.shouldUseLocationServices = NO;
        self.enableAdvertisingTracking = YES;
        self.shouldUseBluetooth = NO;
        self.flushAt = 20;
        self.flushInterval = 30;
        self.maxQueueSize = 1000;
        self.payloadFilters = @{
            @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
        };
        _factories = [NSMutableArray array];
#if TARGET_OS_IPHONE
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [UIApplication performSelector:@selector(sharedApplication)];
        }
#elif TARGET_OS_OSX
        if ([NSApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [NSApplication performSelector:@selector(sharedApplication)];
        }
#endif
    }
    return self;
}

- (void)use:(id<YMIntegrationFactory>)factory
{
    [self.factories addObject:factory];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"writeKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

// MARK: remove these when `middlewares` property is removed.

- (void)setMiddlewares:(NSArray<id<YMMiddleware>> *)middlewares
{
    self.sourceMiddleware = middlewares;
}

- (NSArray<id<YMMiddleware>> *)middlewares
{
    return self.sourceMiddleware;
}

@end
