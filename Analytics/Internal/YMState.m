//
//  YMState.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMState.h"
#import "YMAnalytics.h"
#import "YMAnalyticsUtils.h"
#import "YMReachability.h"
#import "YMUtils.h"

typedef void (^YMStateSetBlock)(void);
typedef _Nullable id (^YMStateGetBlock)(void);


@interface YMState()
// State Objects
@property (nonatomic, nonnull) YMUserInfo *userInfo;
@property (nonatomic, nonnull) YMPayloadContext *context;
// State Accessors
- (void)setValueWithBlock:(YMStateSetBlock)block;
- (id)valueWithBlock:(YMStateGetBlock)block;
@end


@protocol YMStateObject
@property (nonatomic, weak) YMState *state;
- (instancetype)initWithState:(YMState *)state;
@end


@interface YMUserInfo () <YMStateObject>
@end

@interface YMPayloadContext () <YMStateObject>
@property (nonatomic, strong) YMReachability *reachability;
@property (nonatomic, strong) NSDictionary *cachedStaticContext;
@end

#pragma mark - YMUserInfo

@implementation YMUserInfo

@synthesize state;

@synthesize anonymousId = _anonymousId;
@synthesize userId = _userId;
@synthesize traits = _traits;

- (instancetype)initWithState:(YMState *)state
{
    if (self = [super init]) {
        self.state = state;
    }
    return self;
}

- (NSString *)anonymousId
{
    return [state valueWithBlock: ^id{
        return self->_anonymousId;
    }];
}

- (void)setAnonymousId:(NSString *)anonymousId
{
    [state setValueWithBlock: ^{
        self->_anonymousId = [anonymousId copy];
    }];
}

- (NSString *)userId
{
    return [state valueWithBlock: ^id{
        return self->_userId;
    }];
}

- (void)setUserId:(NSString *)userId
{
    [state setValueWithBlock: ^{
        self->_userId = [userId copy];
    }];
}

- (NSDictionary *)traits
{
    return [state valueWithBlock:^id{
        return self->_traits;
    }];
}

- (void)setTraits:(NSDictionary *)traits
{
    [state setValueWithBlock: ^{
        self->_traits = [traits serializableDeepCopy];
    }];
}

@end


#pragma mark - YMPayloadContext

@implementation YMPayloadContext

@synthesize state;
@synthesize reachability;

@synthesize referrer = _referrer;
@synthesize cachedStaticContext = _cachedStaticContext;
@synthesize deviceToken = _deviceToken;

- (instancetype)initWithState:(YMState *)state
{
    if (self = [super init]) {
        self.state = state;
        self.reachability = [YMReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
    }
    return self;
}

- (void)updateStaticContext
{
    self.cachedStaticContext = getStaticContext(state.configuration, self.deviceToken);
}

- (NSDictionary *)payload
{
    NSMutableDictionary *result = [self.cachedStaticContext mutableCopy];
    [result addEntriesFromDictionary:getLiveContext(self.reachability, self.referrer, state.userInfo.traits)];
    return result;
}

- (NSDictionary *)referrer
{
    return [state valueWithBlock:^id{
        return self->_referrer;
    }];
}

- (void)setReferrer:(NSDictionary *)referrer
{
    [state setValueWithBlock: ^{
        self->_referrer = [referrer serializableDeepCopy];
    }];
}

- (NSString *)deviceToken
{
    return [state valueWithBlock:^id{
        return self->_deviceToken;
    }];
}

- (void)setDeviceToken:(NSString *)deviceToken
{
    [state setValueWithBlock: ^{
        self->_deviceToken = [deviceToken copy];
    }];
    [self updateStaticContext];
}

@end


#pragma mark - YMState

@implementation YMState {
    dispatch_queue_t _stateQueue;
}

// TODO: Make this not a singleton.. :(
+ (instancetype)sharedInstance
{
    static YMState *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _stateQueue = dispatch_queue_create("com.yuktamedia.state.queue", DISPATCH_QUEUE_CONCURRENT);
        self.userInfo = [[YMUserInfo alloc] initWithState:self];
        self.context = [[YMPayloadContext alloc] initWithState:self];
    }
    return self;
}

- (void)setValueWithBlock:(YMStateSetBlock)block
{
    dispatch_barrier_async(_stateQueue, block);
}

- (id)valueWithBlock:(YMStateGetBlock)block
{
    __block id value = nil;
    dispatch_sync(_stateQueue, ^{
        value = block();
    });
    return value;
}

@end
