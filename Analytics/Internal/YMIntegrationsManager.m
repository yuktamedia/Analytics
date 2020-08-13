//
//  YMIntegrationsManager.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#import <objc/runtime.h>
#import "YMAnalyticsUtils.h"
#import "YMAnalytics.h"
#import "YMIntegrationFactory.h"
#import "YMIntegration.h"
#import "YMHTTPClient.h"
#import "YMStorage.h"
#import "YMFileStorage.h"
#import "YMUserDefaultsStorage.h"
#import "YMIntegrationsManager.h"
#import "YMAnalyticsIntegrationFactory.h"
#import "YMPayload.h"
#import "YMIdentifyPayload.h"
#import "YMTrackPayload.h"
#import "YMGroupPayload.h"
#import "YMScreenPayload.h"
#import "YMAliasPayload.h"
#import "YMUtils.h"
#import "YMState.h"

NSString *YMAnalyticsIntegrationDidStart = @"io.segment.analytics.integration.did.start";
NSString *const YMAnonymousIdKey = @"YMAnonymousId";
NSString *const kYMAnonymousIdFilename = @"segment.anonymousId";
NSString *const kYMCachedSettingsFilename = @"analytics.settings.v2.plist";


@interface YMIdentifyPayload (AnonymousId)
@property (nonatomic, readwrite, nullable) NSString *anonymousId;
@end


@interface YMPayload (Options)
@property (readonly) NSDictionary *options;
@end
@implementation YMPayload (Options)
// Combine context and integrations to form options
- (NSDictionary *)options
{
    return @{
        @"context" : self.context ?: @{},
        @"integrations" : self.integrations ?: @{}
    };
}
@end


@interface YMAnalyticsConfiguration (Private)
@property (nonatomic, strong) NSArray *factories;
@end


@interface YMIntegrationsManager ()

@property (nonatomic, strong) YMAnalytics *analytics;
@property (nonatomic, strong) NSDictionary *cachedSettings;
@property (nonatomic, strong) YMAnalyticsConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) NSArray *factories;
@property (nonatomic, strong) NSMutableDictionary *integrations;
@property (nonatomic, strong) NSMutableDictionary *registeredIntegrations;
@property (nonatomic, strong) NSMutableDictionary *integrationMiddleware;
@property (nonatomic) volatile BOOL initialized;
@property (nonatomic, copy) NSString *cachedAnonymousId;
@property (nonatomic, strong) YMHTTPClient *httpClient;
@property (nonatomic, strong) NSURLSessionDataTask *settingsRequest;
@property (nonatomic, strong) id<YMStorage> userDefaultsStorage;
@property (nonatomic, strong) id<YMStorage> fileStorage;

@end


@implementation YMIntegrationsManager

@dynamic cachedAnonymousId;
@synthesize cachedSettings = _cachedSettings;

- (instancetype _Nonnull)initWithAnalytics:(YMAnalytics *_Nonnull)analytics
{
    YMAnalyticsConfiguration *configuration = analytics.configuration;
    NSCParameterAssert(configuration != nil);

    if (self = [super init]) {
        self.analytics = analytics;
        self.configuration = configuration;
        self.serialQueue = ym_dispatch_queue_create_specific("com.yuktamedia.analytics", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        self.httpClient = [[YMHTTPClient alloc] initWithRequestFactory:configuration.requestFactory];
        
        self.userDefaultsStorage = [[YMUserDefaultsStorage alloc] initWithDefaults:[NSUserDefaults standardUserDefaults] namespacePrefix:nil crypto:configuration.crypto];
        #if TARGET_OS_TV
            self.fileStorage = [[YMFileStorage alloc] initWithFolder:[YMFileStorage cachesDirectoryURL] crypto:configuration.crypto];
        #else
            self.fileStorage = [[YMFileStorage alloc] initWithFolder:[YMFileStorage applicationSupportDirectoryURL] crypto:configuration.crypto];
        #endif

        self.cachedAnonymousId = [self loadOrGenerateAnonymousID:NO];
        NSMutableArray *factories = [[configuration factories] mutableCopy];
        [factories addObject:[[YMAnalyticsIntegrationFactory alloc] initWithHTTPClient:self.httpClient fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage]];
        self.factories = [factories copy];
        self.integrations = [NSMutableDictionary dictionaryWithCapacity:factories.count];
        self.registeredIntegrations = [NSMutableDictionary dictionaryWithCapacity:factories.count];
        self.integrationMiddleware = [NSMutableDictionary dictionaryWithCapacity:factories.count];

        // Update settings on each integration immediately
        [self refreshSettings];

        // Update settings on foreground
        id<YMApplicationProtocol> application = configuration.application;
        if (application) {
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IPHONE
            [nc addObserver:self selector:@selector(onAppForeground:) name:UIApplicationWillEnterForegroundNotification object:application];
#elif TARGET_OS_OSX
            [nc addObserver:self selector:@selector(onAppForeground:) name:NSApplicationWillUnhideNotification object:application];
#endif
        }
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setCachedAnonymousId:(NSString *)cachedAnonymousId
{
    [YMState sharedInstance].userInfo.anonymousId = cachedAnonymousId;
}

- (NSString *)cachedAnonymousId
{
    NSString *value = [YMState sharedInstance].userInfo.anonymousId;
    return value;
}

- (void)onAppForeground:(NSNotification *)note
{
    [self refreshSettings];
}

- (void)handleAppStateNotification:(NSString *)notificationName
{
    YMLog(@"Application state change notification: %@", notificationName);
    static NSDictionary *selectorMapping;
    static dispatch_once_t selectorMappingOnce;
    dispatch_once(&selectorMappingOnce, ^{
#if TARGET_OS_IPHONE

        selectorMapping = @{
            UIApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            UIApplicationDidEnterBackgroundNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            UIApplicationWillEnterForegroundNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            UIApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
            UIApplicationWillResignActiveNotification :
                NSStringFromSelector(@selector(applicationWillResignActive)),
            UIApplicationDidBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationDidBecomeActive))
        };
#elif TARGET_OS_OSX
        selectorMapping = @{
            NSApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            NSApplicationDidHideNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            NSApplicationWillUnhideNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            NSApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
            NSApplicationWillResignActiveNotification :
                NSStringFromSelector(@selector(applicationWillResignActive)),
            NSApplicationDidBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationDidBecomeActive))
        };
#endif

    });
    SEL selector = NSSelectorFromString(selectorMapping[notificationName]);
    if (selector) {
        [self callIntegrationsWithSelector:selector arguments:nil options:nil sync:true];
    }
}

#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - Analytics API

- (void)identify:(YMIdentifyPayload *)payload
{
    NSCAssert2(payload.userId.length > 0 || payload.traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", payload.userId, payload.traits);

    NSString *anonymousId = payload.anonymousId;
    NSString *existingAnonymousId = self.cachedAnonymousId;
    
    if (anonymousId == nil) {
        payload.anonymousId = anonymousId;
    } else if (![anonymousId isEqualToString:existingAnonymousId]) {
        [self saveAnonymousId:anonymousId];
    }

    [self callIntegrationsWithSelector:NSSelectorFromString(@"identify:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Track

- (void)track:(YMTrackPayload *)payload
{
    NSCAssert1(payload.event.length > 0, @"event (%@) must not be empty.", payload.event);

    [self callIntegrationsWithSelector:NSSelectorFromString(@"track:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Screen

- (void)screen:(YMScreenPayload *)payload
{
    NSCAssert1(payload.name.length > 0, @"screen name (%@) must not be empty.", payload.name);

    [self callIntegrationsWithSelector:NSSelectorFromString(@"screen:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Group

- (void)group:(YMGroupPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"group:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Alias

- (void)alias:(YMAliasPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"alias:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ userInfo ] options:nil sync:true];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ error ] options:nil sync:true];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);

    [self callIntegrationsWithSelector:_cmd arguments:@[ deviceToken ] options:nil sync:true];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ identifier, userInfo ] options:nil sync:true];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ activity ] options:nil sync:true];
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ url, options ] options:nil sync:true];
}

- (void)reset
{
    [self resetAnonymousId];
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

- (void)resetAnonymousId
{
    self.cachedAnonymousId = [self loadOrGenerateAnonymousID:YES];
}

- (NSString *)getAnonymousId;
{
    return self.cachedAnonymousId;
}

- (NSString *)loadOrGenerateAnonymousID:(BOOL)reset
{
#if TARGET_OS_TV
    NSString *anonymousId = [self.userDefaultsStorage stringForKey:YMAnonymousIdKey];
#else
    NSString *anonymousId = [self.fileStorage stringForKey:kYMAnonymousIdFilename];
#endif

    if (!anonymousId || reset) {
        // We've chosen to generate a UUID rather than use the UDID (deprecated in iOS 5),
        // identifierForVendor (iOS6 and later, can't be changed on logout),
        // or MAC address (blocked in iOS 7). For more info see https://segment.io/libraries/ios#ids
        anonymousId = GenerateUUIDString();
        YMLog(@"New anonymousId: %@", anonymousId);
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:anonymousId forKey:YMAnonymousIdKey];
#else
        [self.fileStorage setString:anonymousId forKey:kYMAnonymousIdFilename];
#endif
    }
    
    return anonymousId;
}

- (void)saveAnonymousId:(NSString *)anonymousId
{
    self.cachedAnonymousId = anonymousId;
#if TARGET_OS_TV
    [self.userDefaultsStorage setString:anonymousId forKey:YMAnonymousIdKey];
#else
    [self.fileStorage setString:anonymousId forKey:kYMAnonymousIdFilename];
#endif
}

- (void)flush
{
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

#pragma mark - Analytics Settings

- (NSDictionary *)cachedSettings
{
    if (!_cachedSettings) {
#if TARGET_OS_TV
        _cachedSettings = [self.userDefaultsStorage dictionaryForKey:kYMCachedSettingsFilename] ?: @{};
#else
        _cachedSettings = [self.fileStorage dictionaryForKey:kYMCachedSettingsFilename] ?: @{};
#endif
    }
    
    return _cachedSettings;
}

- (void)setCachedSettings:(NSDictionary *)settings
{
    _cachedSettings = [settings copy];
    if (!_cachedSettings) {
        // [@{} writeToURL:settingsURL atomically:YES];
        return;
    }
    
#if TARGET_OS_TV
    [self.userDefaultsStorage setDictionary:_cachedSettings forKey:kYMCachedSettingsFilename];
#else
    [self.fileStorage setDictionary:_cachedSettings forKey:kYMCachedSettingsFilename];
#endif

    [self updateIntegrationsWithSettings:settings[@"integrations"]];
}

- (nonnull NSArray<id<YMMiddleware>> *)middlewareForIntegrationKey:(NSString *)key
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (YMDestinationMiddleware *container in self.configuration.destinationMiddleware) {
        if ([container.integrationKey isEqualToString:key]) {
            [result addObjectsFromArray:container.middleware];
        }
    }
    return result;
}

- (void)updateIntegrationsWithSettings:(NSDictionary *)projectSettings
{
    ym_dispatch_specific_sync(_serialQueue, ^{
        if (self.initialized) {
            return;
        }
        for (id<YMIntegrationFactory> factory in self.factories) {
            NSString *key = [factory key];
            NSDictionary *integrationSettings = [projectSettings objectForKey:key];
            if (isUnitTesting()) {
                integrationSettings = @{};
            }
            if (integrationSettings) {
                id<YMIntegration> integration = [factory createWithSettings:integrationSettings forAnalytics:self.analytics];
                if (integration != nil) {
                    self.integrations[key] = integration;
                    self.registeredIntegrations[key] = @NO;
                    
                    // setup integration middleware
                    NSArray<id<YMMiddleware>> *middleware = [self middlewareForIntegrationKey:key];
                    self.integrationMiddleware[key] = [[YMMiddlewareRunner alloc] initWithMiddleware:middleware];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:YMAnalyticsIntegrationDidStart object:key userInfo:nil];
            } else {
                YMLog(@"No settings for %@. Skipping.", key);
            }
        }
        [self flushMessageQueue];
        self.initialized = true;
    });
}

- (void)refreshSettings
{
    ym_dispatch_specific_async(_serialQueue, ^{
        if (self.settingsRequest) {
            return;
        }

        self.settingsRequest = [self.httpClient settingsForWriteKey:self.configuration.writeKey completionHandler:^(BOOL success, NSDictionary *settings) {
            ym_dispatch_specific_async(self -> _serialQueue, ^{
                if (success) {
                    [self setCachedSettings:settings];
                } else {
                    NSDictionary *previouslyCachedSettings = [self cachedSettings];
                    if (previouslyCachedSettings && [previouslyCachedSettings count] > 0) {
                        [self setCachedSettings:previouslyCachedSettings];
                    } else if (self.configuration.defaultSettings != nil) {
                        // If settings request fail, load a user-supplied version if present.
                        // but make sure segment.io is in the integrations
                        NSMutableDictionary *newSettings = [self.configuration.defaultSettings serializableMutableDeepCopy];
                        newSettings[@"integrations"][@"YuktaOne.io"][@"apiKey"] = self.configuration.writeKey;
                        [self setCachedSettings:newSettings];
                    } else {
                        // If settings request fail, fall back to using just Analytics integration.
                        // Doesn't address situations where this callback never gets called (though we don't expect that to ever happen).
                        [self setCachedSettings:@{
                            @"integrations" : @{
                                @"YuktaOne.io" : @{@"apiKey" : self.configuration.writeKey},
                            },
                            @"plan" : @{@"track" : @{}}
                        }];
                    }
                }
                self.settingsRequest = nil;
            });
        }];
    });
}

#pragma mark - Private

+ (BOOL)isIntegration:(NSString *)key enabledInOptions:(NSDictionary *)options
{
    // If the event is in the tracking plan, it should always be sent to api.segment.io.
    if ([@"YuktaOne.io" isEqualToString:key]) {
        return YES;
    }
    if (options[key]) {
        id value = options[key];
        
        // it's been observed that customers sometimes override this with
        // value's that aren't bool types.
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *numberValue = (NSNumber *)value;
            return [numberValue boolValue];
        } if ([value isKindOfClass:[NSDictionary class]]) {
            return YES;
        } else {
            NSString *msg = [NSString stringWithFormat: @"Value for `%@` in integration options is supposed to be a boolean or dictionary and it is not!"
                             "This is likely due to a user-added value in `integrations` that overwrites a value received from the server", key];
            YMLog(msg);
            NSAssert(NO, msg);
        }
    } else if (options[@"All"]) {
        return [options[@"All"] boolValue];
    } else if (options[@"all"]) {
        return [options[@"all"] boolValue];
    }
    return YES;
}

+ (BOOL)isTrackEvent:(NSString *)event enabledForIntegration:(NSString *)key inPlan:(NSDictionary *)plan
{
    // Whether the event is enabled or disabled, it should always be sent to api.segment.io.
    if ([key isEqualToString:@"YuktaOne.io"]) {
        return YES;
    }

    if (plan[@"track"][event]) {
        if ([plan[@"track"][event][@"enabled"] boolValue]) {
            return [self isIntegration:key enabledInOptions:plan[@"track"][event][@"integrations"]];
        } else {
            return NO;
        }
    } else if (plan[@"track"][@"__default"]) {
        return [plan[@"track"][@"__default"][@"enabled"] boolValue];
    }

    return YES;
}

- (void)forwardSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    [self.integrations enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<YMIntegration> integration, BOOL *stop) {
        [self invokeIntegration:integration key:key selector:selector arguments:arguments options:options];
    }];
}

/*
 This kind of sucks, but we wrote ourselves into a corner here.  A larger refactor will need to happen.
 I also opted to not put this as a utility function because we shouldn't be doing this in the first place,
 so consider it a one-off.  If you find yourself needing to do this again, lets talk about a refactor.
 */
- (YMEventType)eventTypeFromSelector:(SEL)selector
{
    NSString *selectorString = NSStringFromSelector(selector);
    YMEventType result = YMEventTypeUndefined;
    
    if ([selectorString hasPrefix:@"identify"]) {
        result = YMEventTypeIdentify;
    } else if ([selectorString hasPrefix:@"track"]) {
        result = YMEventTypeTrack;
    } else if ([selectorString hasPrefix:@"screen"]) {
        result = YMEventTypeScreen;
    } else if ([selectorString hasPrefix:@"group"]) {
        result = YMEventTypeGroup;
    } else if ([selectorString hasPrefix:@"alias"]) {
        result = YMEventTypeAlias;
    } else if ([selectorString hasPrefix:@"reset"]) {
        result = YMEventTypeReset;
    } else if ([selectorString hasPrefix:@"flush"]) {
        result = YMEventTypeFlush;
    } else if ([selectorString hasPrefix:@"receivedRemoteNotification"]) {
        result = YMEventTypeReceivedRemoteNotification;
    } else if ([selectorString hasPrefix:@"failedToRegisterForRemoteNotificationsWithError"]) {
        result = YMEventTypeFailedToRegisterForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"registeredForRemoteNotificationsWithDeviceToken"]) {
        result = YMEventTypeRegisteredForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"handleActionWithIdentifier"]) {
        result = YMEventTypeHandleActionWithForRemoteNotification;
    } else if ([selectorString hasPrefix:@"continueUserActivity"]) {
        result = YMEventTypeContinueUserActivity;
    } else if ([selectorString hasPrefix:@"openURL"]) {
        result = YMEventTypeOpenURL;
    } else if ([selectorString hasPrefix:@"application"]) {
        result = YMEventTypeApplicationLifecycle;
    }

    return result;
}

- (void)invokeIntegration:(id<YMIntegration>)integration key:(NSString *)key selector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    if (![integration respondsToSelector:selector]) {
        YMLog(@"Not sending call to %@ because it doesn't respond to %@.", key, NSStringFromSelector(selector));
        return;
    }

    if (![[self class] isIntegration:key enabledInOptions:options[@"integrations"]]) {
        YMLog(@"Not sending call to %@ because it is disabled in options.", key);
        return;
    }
    
    YMEventType eventType = [self eventTypeFromSelector:selector];
    if (eventType == YMEventTypeTrack) {
        YMTrackPayload *eventPayload = arguments[0];
        BOOL enabled = [[self class] isTrackEvent:eventPayload.event enabledForIntegration:key inPlan:self.cachedSettings[@"plan"]];
        if (!enabled) {
            YMLog(@"Not sending call to %@ because it is disabled in plan.", key);
            return;
        }
    }

    NSMutableArray *newArguments = [arguments mutableCopy];

    if (eventType != YMEventTypeUndefined) {
        YMMiddlewareRunner *runner = self.integrationMiddleware[key];
        if (runner.middlewares.count > 0) {
            YMPayload *payload = nil;
            // things like flush have no args.
            if (arguments.count > 0) {
                payload = arguments[0];
            }
            YMContext *context = [[[YMContext alloc] initWithAnalytics:self.analytics] modify:^(id<YMMutableContext> _Nonnull ctx) {
                ctx.eventType = eventType;
                ctx.payload = payload;
            }];

            context = [runner run:context callback:nil];
            // if we weren't given args, don't set them.
            if (arguments.count > 0) {
                newArguments[0] = context.payload;
            }
        }
    }
    
    YMLog(@"Running: %@ with arguments %@ on integration: %@", NSStringFromSelector(selector), newArguments, key);
    NSInvocation *invocation = [self invocationForSelector:selector arguments:newArguments];
    [invocation invokeWithTarget:integration];
}

- (NSInvocation *)invocationForSelector:(SEL)selector arguments:(NSArray *)arguments
{
    struct objc_method_description description = protocol_getMethodDescription(@protocol(YMIntegration), selector, NO, YES);

    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:description.types];

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    for (int i = 0; i < arguments.count; i++) {
        id argument = (arguments[i] == [NSNull null]) ? nil : arguments[i];
        [invocation setArgument:&argument atIndex:i + 2];
    }
    return invocation;
}

- (void)queueSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSArray *obj = @[ NSStringFromSelector(selector), arguments ?: @[], options ?: @{} ];
    YMLog(@"Queueing: %@", obj);
    [_messageQueue addObject:obj];
}

- (void)flushMessageQueue
{
    if (_messageQueue.count != 0) {
        for (NSArray *arr in _messageQueue)
            [self forwardSelector:NSSelectorFromString(arr[0]) arguments:arr[1] options:arr[2]];
        [_messageQueue removeAllObjects];
    }
}

- (void)callIntegrationsWithSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options sync:(BOOL)sync
{
    // TODO: Currently we ignore the `sync` argument and queue the event asynchronously.
    // For integrations that need events to be on the main thread, they'll have to do so
    // manually and hop back on to the main thread.
    // Eventually we should figure out a way to handle this in analytics-ios itself.
    ym_dispatch_specific_async(_serialQueue, ^{
        if (self.initialized) {
            [self flushMessageQueue];
            [self forwardSelector:selector arguments:arguments options:options];
        } else {
            [self queueSelector:selector arguments:arguments options:options];
        }
    });
}

@end


@implementation YMIntegrationsManager (YMMiddleware)

- (void)context:(YMContext *)context next:(void (^_Nonnull)(YMContext *_Nullable))next
{
    switch (context.eventType) {
        case YMEventTypeIdentify: {
            YMIdentifyPayload *p = (YMIdentifyPayload *)context.payload;
            [self identify:p];
            break;
        }
        case YMEventTypeTrack: {
            YMTrackPayload *p = (YMTrackPayload *)context.payload;
            [self track:p];
            break;
        }
        case YMEventTypeScreen: {
            YMScreenPayload *p = (YMScreenPayload *)context.payload;
            [self screen:p];
            break;
        }
        case YMEventTypeGroup: {
            YMGroupPayload *p = (YMGroupPayload *)context.payload;
            [self group:p];
            break;
        }
        case YMEventTypeAlias: {
            YMAliasPayload *p = (YMAliasPayload *)context.payload;
            [self alias:p];
            break;
        }
        case YMEventTypeReset:
            [self reset];
            break;
        case YMEventTypeFlush:
            [self flush];
            break;
        case YMEventTypeReceivedRemoteNotification:
            [self receivedRemoteNotification:
                      [(YMRemoteNotificationPayload *)context.payload userInfo]];
            break;
        case YMEventTypeFailedToRegisterForRemoteNotifications:
            [self failedToRegisterForRemoteNotificationsWithError:
                      [(YMRemoteNotificationPayload *)context.payload error]];
            break;
        case YMEventTypeRegisteredForRemoteNotifications:
            [self registeredForRemoteNotificationsWithDeviceToken:
                      [(YMRemoteNotificationPayload *)context.payload deviceToken]];
            break;
        case YMEventTypeHandleActionWithForRemoteNotification: {
            YMRemoteNotificationPayload *payload = (YMRemoteNotificationPayload *)context.payload;
            [self handleActionWithIdentifier:payload.actionIdentifier
                       forRemoteNotification:payload.userInfo];
            break;
        }
        case YMEventTypeContinueUserActivity:
            [self continueUserActivity:
                      [(YMContinueUserActivityPayload *)context.payload activity]];
            break;
        case YMEventTypeOpenURL: {
            YMOpenURLPayload *payload = (YMOpenURLPayload *)context.payload;
            [self openURL:payload.url options:payload.options];
            break;
        }
        case YMEventTypeApplicationLifecycle:
            [self handleAppStateNotification:
                      [(YMApplicationLifecyclePayload *)context.payload notificationName]];
            break;
        default:
        case YMEventTypeUndefined:
            NSAssert(NO, @"Received context with undefined event type %@", context);
            YMLog(@"[ERROR]: Received context with undefined event type %@", context);
            break;
    }
    next(context);
}

@end
