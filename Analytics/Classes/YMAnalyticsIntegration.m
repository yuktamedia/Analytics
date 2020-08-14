//
//  YMAnalyticsIntegration.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#include <sys/sysctl.h>

#import "YMAnalytics.h"
#import "YMUtils.h"
#import "YMAnalyticsIntegration.h"
#import "YMReachability.h"
#import "YMHTTPClient.h"
#import "YMStorage.h"
#import "YMMacros.h"
#import "YMState.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_IOS
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

NSString *const YMAnalyticsDidSendRequestNotification = @"AnalyticsDidSendRequest";
NSString *const YMAnalyticsRequestDidSucceedNotification = @"AnalyticsRequestDidSucceed";
NSString *const YMAnalyticsRequestDidFailNotification = @"AnalyticsRequestDidFail";

NSString *const YMUserIdKey = @"YMUserId";
NSString *const YMQueueKey = @"YMQueue";
NSString *const YMTraitsKey = @"YMTraits";

NSString *const kYMUserIdFilename = @"yuktaoneio.userId";
NSString *const kYMQueueFilename = @"yuktaoneio.queue.plist";
NSString *const kYMTraitsFilename = @"yuktaoneio.traits.plist";

@interface YMAnalyticsIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, strong) YMReachability *reachability;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;
@property (nonatomic, strong) NSDictionary *traits;
@property (nonatomic, assign) YMAnalytics *analytics;
@property (nonatomic, assign) YMAnalyticsConfiguration *configuration;
@property (atomic, copy) NSDictionary *referrer;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) NSURL *apiURL;
@property (nonatomic, strong) YMHTTPClient *httpClient;
@property (nonatomic, strong) id<YMStorage> fileStorage;
@property (nonatomic, strong) id<YMStorage> userDefaultsStorage;
@property (nonatomic, strong) NSURLSessionDataTask *attributionRequest;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
#endif

@end


@implementation YMAnalyticsIntegration

- (id)initWithAnalytics:(YMAnalytics *)analytics httpClient:(YMHTTPClient *)httpClient fileStorage:(id<YMStorage>)fileStorage userDefaultsStorage:(id<YMStorage>)userDefaultsStorage;
{
    if (self = [super init]) {
        self.analytics = analytics;
        self.configuration = analytics.configuration;
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = analytics.configuration.httpSessionDelegate;
        self.fileStorage = fileStorage;
        self.userDefaultsStorage = userDefaultsStorage;
        self.apiURL = [YUKTAMEDIA_API_BASE URLByAppendingPathComponent:@"datasync-android"];
        self.reachability = [YMReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.serialQueue = ym_dispatch_queue_create_specific("io.yuktaone.analytics.yuktaoneio", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = ym_dispatch_queue_create_specific("io.yuktaone.analytics.backgroundTask", DISPATCH_QUEUE_SERIAL);
#if TARGET_OS_IPHONE
        self.flushTaskID = UIBackgroundTaskInvalid;
#endif
        
        // load traits & user from disk.
        [self loadUserId];
        [self loadTraits];

        [self dispatchBackground:^{
            // Check for previous queue data in NSUserDefaults and remove if present.
            if ([[NSUserDefaults standardUserDefaults] objectForKey:YMQueueKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:YMQueueKey];
            }
#if !TARGET_OS_TV
            // Check for previous track data in NSUserDefaults and remove if present (Traits still exist in NSUserDefaults on tvOS)
            if ([[NSUserDefaults standardUserDefaults] objectForKey:YMTraitsKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:YMTraitsKey];
            }
#endif
        }];
        [self dispatchBackground:^{
            [self trackAttributionData:self.configuration.trackAttributionData];
        }];

        self.flushTimer = [NSTimer timerWithTimeInterval:self.configuration.flushInterval
                                                  target:self
                                                selector:@selector(flush)
                                                userInfo:nil
                                                 repeats:YES];
        
        [NSRunLoop.mainRunLoop addTimer:self.flushTimer
                                forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)dispatchBackground:(void (^)(void))block
{
    ym_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    ym_dispatch_specific_sync(_serialQueue, block);
}

#if TARGET_OS_IPHONE
- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    ym_dispatch_specific_sync(_backgroundTaskQueue, ^{
        
        id<YMApplicationProtocol> application = [self.analytics configuration].application;
        if (application && [application respondsToSelector:@selector(ym_beginBackgroundTaskWithName:expirationHandler:)]) {
            self.flushTaskID = [application ym_beginBackgroundTaskWithName:@"Analyticsio.Flush"
                                                          expirationHandler:^{
                                                              [self endBackgroundTask];
                                                          }];
        }
    });
}

- (void)endBackgroundTask
{
    // endBackgroundTask and beginBackgroundTask can be called from main thread
    // We should not dispatch to the same queue we use to flush events because it can cause deadlock
    // inside @synchronized(self) block for YMIntegrationsManager as both events queue and main queue
    // attempt to call forwardSelector:arguments:options:
    // See https://github.com/yuktaoneio/analytics-ios/issues/683
    ym_dispatch_specific_sync(_backgroundTaskQueue, ^{
        if (self.flushTaskID != UIBackgroundTaskInvalid) {
            id<YMApplicationProtocol> application = [self.analytics configuration].application;
            if (application && [application respondsToSelector:@selector(ym_endBackgroundTask:)]) {
                [application ym_endBackgroundTask:self.flushTaskID];
            }

            self.flushTaskID = UIBackgroundTaskInvalid;
        }
    });
}
#endif

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.writeKey];
}

- (NSString *)userId
{
    return [YMState sharedInstance].userInfo.userId;
}

- (void)setUserId:(NSString *)userId
{
    [self dispatchBackground:^{
        [YMState sharedInstance].userInfo.userId = userId;
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:userId forKey:YMUserIdKey];
#else
        [self.fileStorage setString:userId forKey:kYMUserIdFilename];
#endif
    }];
}

- (NSDictionary *)traits
{
    return [YMState sharedInstance].userInfo.traits;
}

- (void)setTraits:(NSDictionary *)traits
{
    [self dispatchBackground:^{
        [YMState sharedInstance].userInfo.traits = traits;
#if TARGET_OS_TV
        [self.userDefaultsStorage setDictionary:[self.traits copy] forKey:YMTraitsKey];
#else
        [self.fileStorage setDictionary:[self.traits copy] forKey:kYMTraitsFilename];
#endif
    }];
}

#pragma mark - Analytics API

- (void)identify:(YMIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        self.userId = payload.userId;
        self.traits = payload.traits;
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
    [self enqueueAction:@"identify" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)track:(YMTrackPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"event"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
    [self enqueueAction:@"track" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)screen:(YMScreenPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.name forKey:@"name"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"screen" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)group:(YMGroupPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.groupId forKey:@"groupId"];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"group" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)alias:(YMAliasPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.theNewId forKey:@"userId"];
    [dictionary setValue:self.userId ?: [self.analytics getAnonymousId] forKey:@"previousId"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"alias" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

#pragma mark - Queueing

// Merges user provided integration options with bundled integrations.
- (NSDictionary *)integrationsDictionary:(NSDictionary *)integrations
{
    NSMutableDictionary *dict = [integrations ?: @{} mutableCopy];
    for (NSString *integration in self.analytics.bundledIntegrations) {
        // Don't record Analytics.io in the dictionary. It is always enabled.
        if ([integration isEqualToString:@"YuktaOne.io"]) {
            continue;
        }
        dict[integration] = @NO;
    }
    return [dict copy];
}

- (void)enqueueAction:(NSString *)action dictionary:(NSMutableDictionary *)payload context:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    // attach these parts of the payload outside since they are all synchronous
    payload[@"type"] = action;

    [self dispatchBackground:^{
        // attach userId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        // Do not override the userId for an 'alias' action. This value is set in [alias:] already.
        if (![action isEqualToString:@"alias"]) {
            [payload setValue:[YMState sharedInstance].userInfo.userId forKey:@"userId"];
        }
        [payload setValue:[self.analytics getAnonymousId] forKey:@"anonymousId"];

        [payload setValue:[self integrationsDictionary:integrations] forKey:@"integrations"];

        [payload setValue:[context copy] forKey:@"context"];

        YMLog(@"%@ Enqueueing action: %@", self, payload);
        
        NSDictionary *queuePayload = [payload copy];
        
        if (self.configuration.experimental.rawAnalyticsModificationBlock != nil) {
            NSDictionary *tempPayload = self.configuration.experimental.rawAnalyticsModificationBlock(queuePayload);
            if (tempPayload == nil) {
                YMLog(@"rawAnalyticsModificationBlock cannot be used to drop events!");
            } else {
                // prevent anything else from modifying it at this point.
                queuePayload = [tempPayload copy];
            }
        }
        [self queuePayload:queuePayload];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
        // Trim the queue to maxQueueSize - 1 before we add a new element.
        trimQueue(self.queue, self.analytics.configuration.maxQueueSize - 1);
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];
    }
    @catch (NSException *exception) {
        YMLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    void (^startBatch)(void) = ^{
        NSArray *batch;
        if ([self.queue count] >= maxBatchSize) {
            batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
        } else {
            batch = [NSArray arrayWithArray:self.queue];
        }
        [self sendData:batch];
    };
    
#if TARGET_OS_IPHONE
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            YMLog(@"%@ No queued API calls to flush.", self);
            [self endBackgroundTask];
            return;
        }
        if (self.batchRequest != nil) {
            YMLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        }
        // here
        startBatch();
    }];
#elif TARGET_OS_OSX
    startBatch();
#endif
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        YMLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.batchRequest == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
#if TARGET_OS_TV
        [self.userDefaultsStorage removeKey:YMUserIdKey];
        [self.userDefaultsStorage removeKey:YMTraitsKey];
#else
        [self.fileStorage removeKey:kYMUserIdFilename];
        [self.fileStorage removeKey:kYMTraitsFilename];
#endif
        self.userId = nil;
        self.traits = [NSMutableDictionary dictionary];
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:userInfo];
        YMLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSArray *)batch
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setObject:iso8601FormattedString([NSDate date]) forKey:@"sentAt"];
    [payload setObject:batch forKey:@"batch"];

    YMLog(@"%@ Flushing %lu of %lu queued API calls.", self, (unsigned long)batch.count, (unsigned long)self.queue.count);
    YMLog(@"Flushing batch %@.", payload);

    self.batchRequest = [self.httpClient upload:payload forWriteKey:self.configuration.writeKey completionHandler:^(BOOL retry) {
        
#if TARGET_OS_IPHONE
        void (^completion)(void) = ^{
            if (retry) {
                [self notifyForName:YMAnalyticsRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                [self endBackgroundTask];
                return;
            }

            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:YMAnalyticsRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
            [self endBackgroundTask];
        };
#elif TARGET_OS_OSX
        void (^completion)(void) = ^{
            if (retry) {
                [self notifyForName:YMAnalyticsRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                return;
            }

            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:YMAnalyticsRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
        };
#endif
        
        [self dispatchBackground:completion];
    }];

    [self notifyForName:YMAnalyticsDidSendRequestNotification userInfo:batch];
}

#if TARGET_OS_IPHONE
- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}
#endif

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)
            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
        _queue = [[self.fileStorage arrayForKey:kYMQueueFilename] ?: @[] mutableCopy];
    }

    return _queue;
}

- (void)loadTraits
{
    if (![YMState sharedInstance].userInfo.traits) {
        NSDictionary *traits = nil;
#if TARGET_OS_TV
        traits = [[self.userDefaultsStorage dictionaryForKey:YMTraitsKey] ?: @{} mutableCopy];
#else
        traits = [[self.fileStorage dictionaryForKey:kYMTraitsFilename] ?: @{} mutableCopy];
#endif
        [YMState sharedInstance].userInfo.traits = traits;
    }
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (void)loadUserId
{
    NSString *result = nil;
#if TARGET_OS_TV
    result = [[NSUserDefaults standardUserDefaults] valueForKey:YMUserIdKey];
#else
    result = [self.fileStorage stringForKey:kYMUserIdFilename];
#endif
    [YMState sharedInstance].userInfo.userId = result;
}

- (void)persistQueue
{
    [self.fileStorage setArray:[self.queue copy] forKey:kYMQueueFilename];
}

NSString *const YMTrackedAttributionKey = @"YMTrackedAttributionKey";

- (void)trackAttributionData:(BOOL)trackAttributionData
{
#if TARGET_OS_IPHONE
    if (!trackAttributionData) {
        return;
    }

    BOOL trackedAttribution = [[NSUserDefaults standardUserDefaults] boolForKey:YMTrackedAttributionKey];
    if (trackedAttribution) {
        return;
    }

    NSDictionary *context = [YMState sharedInstance].context.payload;

    self.attributionRequest = [self.httpClient attributionWithWriteKey:self.configuration.writeKey forDevice:[context copy] completionHandler:^(BOOL success, NSDictionary *properties) {
        [self dispatchBackground:^{
            if (success) {
                [self.analytics track:@"Install Attributed" properties:properties];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:YMTrackedAttributionKey];
            }
            self.attributionRequest = nil;
        }];
    }];
#endif
}

@end
