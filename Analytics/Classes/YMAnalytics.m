//
//  YMAnalytics.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <objc/runtime.h>
#import "YMAnalyticsUtils.h"
#import "YMAnalytics.h"
#import "YMIntegrationFactory.h"
#import "YMIntegration.h"
#import "YMAnalyticsIntegrationFactory.h"
#import "UIViewController+YMScreen.h"
#import "NSViewController+YMScreen.h"
#import "YMStoreKitTracker.h"
#import "YMHTTPClient.h"
#import "YMStorage.h"
#import "YMFileStorage.h"
#import "YMUserDefaultsStorage.h"
#import "YMMiddleware.h"
#import "YMContext.h"
#import "YMIntegrationsManager.h"
#import "YMState.h"
#import "YMUtils.h"

static YMAnalytics *__sharedInstance = nil;


@interface YMAnalytics ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) YMAnalyticsConfiguration *configuration;
@property (nonatomic, strong) YMStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) YMIntegrationsManager *integrationsManager;
@property (nonatomic, strong) YMMiddlewareRunner *runner;

@end


@implementation YMAnalytics

+ (void)setupWithConfiguration:(YMAnalyticsConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(YMAnalyticsConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.configuration = configuration;
        self.enabled = YES;

        // In swift this would not have been OK... But hey.. It's objc
        // TODO: Figure out if this is really the best way to do things here.
        self.integrationsManager = [[YMIntegrationsManager alloc] initWithAnalytics:self];

        self.runner = [[YMMiddlewareRunner alloc] initWithMiddleware:
                                                       [configuration.sourceMiddleware ?: @[] arrayByAddingObject:self.integrationsManager]];

        // Pass through for application state change events
        id<YMApplicationProtocol> application = configuration.application;
        if (application) {
            #if TARGET_OS_IPHONE
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification,
                                      UIApplicationDidFinishLaunchingNotification,
                                      UIApplicationWillEnterForegroundNotification,
                                      UIApplicationWillTerminateNotification,
                                      UIApplicationWillResignActiveNotification,
                                      UIApplicationDidBecomeActiveNotification ]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
            #elif TARGET_OS_OSX
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ NSApplicationWillUnhideNotification,
                                      NSApplicationDidFinishLaunchingNotification,
                                      NSApplicationWillResignActiveNotification,
                                      NSApplicationDidHideNotification,
                                      NSApplicationDidBecomeActiveNotification,
                                      NSApplicationWillTerminateNotification]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
            #endif
        }

        #if TARGET_OS_IPHONE
        if (configuration.recordScreenViews) {
            [UIViewController ym_swizzleViewDidAppear];
        }
        #elif TARGET_OS_OSX
        if (configuration.recordScreenViews) {
            [NSViewController ym_swizzleViewDidAppear];
        }
        #endif
        if (configuration.trackInAppPurchases) {
            _storeKitTracker = [YMStoreKitTracker trackTransactionsForAnalytics:self];
        }

        #if !TARGET_OS_TV
        if (configuration.trackPushNotifications && configuration.launchOptions) {
        #if TARGET_OS_IOS
            NSDictionary *remoteNotification = configuration.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        #else
            NSDictionary *remoteNotification = configuration.launchOptions[NSApplicationLaunchUserNotificationKey];
        #endif
            if (remoteNotification) {
                [self trackPushNotification:remoteNotification fromLaunch:YES];
            }
        }
        #endif
        
        [YMState sharedInstance].configuration = configuration;
        [[YMState sharedInstance].context updateStaticContext];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

NSString *const YMVersionKey = @"YMVersionKey";
NSString *const YMBuildKeyV1 = @"YMBuildKey";
NSString *const YMBuildKeyV2 = @"YMBuildKeyV2";

#if TARGET_OS_IPHONE
- (void)handleAppStateNotification:(NSNotification *)note
{
    YMApplicationLifecyclePayload *payload = [[YMApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:YMEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:UIApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString: UIApplicationDidEnterBackgroundNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#elif TARGET_OS_OSX
- (void)handleAppStateNotification:(NSNotification *)note
{
    YMApplicationLifecyclePayload *payload = [[YMApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:YMEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:NSApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:NSApplicationWillUnhideNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString: NSApplicationDidHideNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#endif

- (void)_applicationDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (!self.configuration.trackApplicationLifecycleEvents) {
        return;
    }
    // Previously YMBuildKey was stored an integer. This was incorrect because the CFBundleVersion
    // can be a string. This migrates YMBuildKey to be stored as a string.
    NSInteger previousBuildV1 = [[NSUserDefaults standardUserDefaults] integerForKey:YMBuildKeyV1];
    if (previousBuildV1) {
        [[NSUserDefaults standardUserDefaults] setObject:[@(previousBuildV1) stringValue] forKey:YMBuildKeyV2];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:YMBuildKeyV1];
    }

    NSString *previousVersion = [[NSUserDefaults standardUserDefaults] stringForKey:YMVersionKey];
    NSString *previousBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:YMBuildKeyV2];

    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];

    if (!previousBuildV2) {
        [self track:@"Application Installed" properties:@{
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    } else if (![currentBuild isEqualToString:previousBuildV2]) {
        [self track:@"Application Updated" properties:@{
            @"previous_version" : previousVersion ?: @"",
            @"previous_build" : previousBuildV2 ?: @"",
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    }

    #if TARGET_OS_IPHONE
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"referring_application" : launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] ?: @"",
        @"url" : launchOptions[UIApplicationLaunchOptionsURLKey] ?: @"",
    }];
    #elif TARGET_OS_OSX
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"default_launch" : launchOptions[NSApplicationLaunchIsDefaultLaunchKey] ?: @(YES),
    }];
    #endif


    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:YMVersionKey];
    [[NSUserDefaults standardUserDefaults] setObject:currentBuild forKey:YMBuildKeyV2];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_applicationWillEnterForeground
{
    if (!self.configuration.trackApplicationLifecycleEvents) {
        return;
    }
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    [self track:@"Application Opened" properties:@{
        @"from_background" : @YES,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
    }];
    
    [[YMState sharedInstance].context updateStaticContext];
}

- (void)_applicationDidEnterBackground
{
  if (!self.configuration.trackApplicationLifecycleEvents) {
    return;
  }
  [self track: @"Application Backgrounded"];
}


#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - Identify

- (void)identify:(NSString *)userId
{
    [self identify:userId traits:nil options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits
{
    [self identify:userId traits:traits options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    NSCAssert2(userId.length > 0 || traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", userId, traits);
    
    // this is done here to match functionality on android where these are inserted BEFORE being spread out amongst destinations.
    // it will be set globally later when it runs through YMIntegrationManager.identify.
    NSString *anonId = [options objectForKey:@"anonymousId"];
    if (anonId == nil) {
        anonId = [self getAnonymousId];
    }
    // configure traits to match what is seen on android.
    NSMutableDictionary *existingTraitsCopy = [[YMState sharedInstance].userInfo.traits mutableCopy];
    NSMutableDictionary *traitsCopy = [traits mutableCopy];
    // if no traits were passed in, need to create.
    if (existingTraitsCopy == nil) {
        existingTraitsCopy = [[NSMutableDictionary alloc] init];
    }
    if (traitsCopy == nil) {
        traitsCopy = [[NSMutableDictionary alloc] init];
    }
    traitsCopy[@"anonymousId"] = anonId;
    if (userId != nil) {
        traitsCopy[@"userId"] = userId;
        [YMState sharedInstance].userInfo.userId = userId;
    }
    // merge w/ existing traits and set them.
    [existingTraitsCopy addEntriesFromDictionary:traits];
    [YMState sharedInstance].userInfo.traits = existingTraitsCopy;
    
    [self run:YMEventTypeIdentify payload:
                                       [[YMIdentifyPayload alloc] initWithUserId:userId
                                                                      anonymousId:anonId
                                                                           traits:YMCoerceDictionary(existingTraitsCopy)
                                                                          context:YMCoerceDictionary([options objectForKey:@"context"])
                                                                     integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Track

- (void)track:(NSString *)event
{
    [self track:event properties:nil options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self track:event properties:properties options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(event.length > 0, @"event (%@) must not be empty.", event);
    [self run:YMEventTypeTrack payload:
                                    [[YMTrackPayload alloc] initWithEvent:event
                                                                properties:YMCoerceDictionary(properties)
                                                                   context:YMCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Screen

- (void)screen:(NSString *)screenTitle
{
    [self screen:screenTitle properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties
{
    [self screen:screenTitle properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(screenTitle.length > 0, @"screen name (%@) must not be empty.", screenTitle);

    [self run:YMEventTypeScreen payload:
                                     [[YMScreenPayload alloc] initWithName:screenTitle
                                                                 properties:YMCoerceDictionary(properties)
                                                                    context:YMCoerceDictionary([options objectForKey:@"context"])
                                                               integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Group

- (void)group:(NSString *)groupId
{
    [self group:groupId traits:nil options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits
{
    [self group:groupId traits:traits options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    [self run:YMEventTypeGroup payload:
                                    [[YMGroupPayload alloc] initWithGroupId:groupId
                                                                      traits:YMCoerceDictionary(traits)
                                                                     context:YMCoerceDictionary([options objectForKey:@"context"])
                                                                integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Alias

- (void)alias:(NSString *)newId
{
    [self alias:newId options:nil];
}

- (void)alias:(NSString *)newId options:(NSDictionary *)options
{
    [self run:YMEventTypeAlias payload:
                                    [[YMAliasPayload alloc] initWithNewId:newId
                                                                   context:YMCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

- (void)trackPushNotification:(NSDictionary *)properties fromLaunch:(BOOL)launch
{
    if (launch) {
        [self track:@"Push Notification Tapped" properties:properties];
    } else {
        [self track:@"Push Notification Received" properties:properties];
    }
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    if (self.configuration.trackPushNotifications) {
        [self trackPushNotification:userInfo fromLaunch:NO];
    }
    YMRemoteNotificationPayload *payload = [[YMRemoteNotificationPayload alloc] init];
    payload.userInfo = userInfo;
    [self run:YMEventTypeReceivedRemoteNotification payload:payload];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    YMRemoteNotificationPayload *payload = [[YMRemoteNotificationPayload alloc] init];
    payload.error = error;
    [self run:YMEventTypeFailedToRegisterForRemoteNotifications payload:payload];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    YMRemoteNotificationPayload *payload = [[YMRemoteNotificationPayload alloc] init];
    payload.deviceToken = deviceToken;
    [YMState sharedInstance].context.deviceToken = deviceTokenToString(deviceToken);
    [self run:YMEventTypeRegisteredForRemoteNotifications payload:payload];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    YMRemoteNotificationPayload *payload = [[YMRemoteNotificationPayload alloc] init];
    payload.actionIdentifier = identifier;
    payload.userInfo = userInfo;
    [self run:YMEventTypeHandleActionWithForRemoteNotification payload:payload];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    YMContinueUserActivityPayload *payload = [[YMContinueUserActivityPayload alloc] init];
    payload.activity = activity;
    [self run:YMEventTypeContinueUserActivity payload:payload];

    if (!self.configuration.trackDeepLinks) {
        return;
    }

    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSString *urlString = activity.webpageURL.absoluteString;
        [YMState sharedInstance].context.referrer = @{
            @"url" : urlString,
        };

        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:activity.userInfo.count + 2];
        [properties addEntriesFromDictionary:activity.userInfo];
        properties[@"url"] = urlString;
        properties[@"title"] = activity.title ?: @"";
        properties = [YMUtils traverseJSON:properties
                      andReplaceWithFilters:self.configuration.payloadFilters];
        [self track:@"Deep Link Opened" properties:[properties copy]];
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    YMOpenURLPayload *payload = [[YMOpenURLPayload alloc] init];
    payload.url = [NSURL URLWithString:[YMUtils traverseJSON:url.absoluteString
                                        andReplaceWithFilters:self.configuration.payloadFilters]];
    payload.options = options;
    [self run:YMEventTypeOpenURL payload:payload];

    if (!self.configuration.trackDeepLinks) {
        return;
    }
    
    NSString *urlString = url.absoluteString;
    [YMState sharedInstance].context.referrer = @{
        @"url" : urlString,
    };

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:options.count + 2];
    [properties addEntriesFromDictionary:options];
    properties[@"url"] = urlString;
    properties = [YMUtils traverseJSON:properties
                  andReplaceWithFilters:self.configuration.payloadFilters];
    [self track:@"Deep Link Opened" properties:[properties copy]];
}

- (void)reset
{
    [self run:YMEventTypeReset payload:nil];
}

- (void)flush
{
    [self run:YMEventTypeFlush payload:nil];
}

- (void)enable
{
    _enabled = YES;
}

- (void)disable
{
    _enabled = NO;
}

- (NSString *)getAnonymousId
{
    return [YMState sharedInstance].userInfo.anonymousId;
}

- (NSString *)getDeviceToken
{
    return [YMState sharedInstance].context.deviceToken;
}

- (NSDictionary *)bundledIntegrations
{
    return [self.integrationsManager.registeredIntegrations copy];
}

#pragma mark - Class Methods

+ (instancetype)sharedAnalytics
{
    NSCAssert(__sharedInstance != nil, @"library must be initialized before calling this method.");
    return __sharedInstance;
}

+ (void)debug:(BOOL)showDebugLogs
{
    YMSetShowDebugLogs(showDebugLogs);
}

+ (NSString *)version
{
    // this has to match the actual version, NOT what's in info.plist
    // because Apple only accepts X.X.X as versions in the review process.
    return @"4.0.4";
}

#pragma mark - Helpers

- (void)run:(YMEventType)eventType payload:(YMPayload *)payload
{
    if (!self.enabled) {
        return;
    }
    
    if (self.configuration.experimental.nanosecondTimestamps) {
        payload.timestamp = iso8601NanoFormattedString([NSDate date]);
    } else {
        payload.timestamp = iso8601FormattedString([NSDate date]);
    }
    
    YMContext *context = [[[YMContext alloc] initWithAnalytics:self] modify:^(id<YMMutableContext> _Nonnull ctx) {
        ctx.eventType = eventType;
        ctx.payload = payload;
        ctx.payload.messageId = GenerateUUIDString();
        if (ctx.payload.userId == nil) {
            ctx.payload.userId = [YMState sharedInstance].userInfo.userId;
        }
        if (ctx.payload.anonymousId == nil) {
            ctx.payload.anonymousId = [YMState sharedInstance].userInfo.anonymousId;
        }
    }];
    
    // Could probably do more things with callback later, but we don't use it yet.
    [self.runner run:context callback:nil];
}

@end
