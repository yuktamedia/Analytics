//
//  YMPayload.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMPayload.h"
#import "YMState.h"

@implementation YMPayload

@synthesize userId = _userId;
@synthesize anonymousId = _anonymousId;

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    if (self = [super init]) {
        // combine existing state with user supplied context.
        NSDictionary *internalContext = [YMState sharedInstance].context.payload;
        
        NSMutableDictionary *combinedContext = [[NSMutableDictionary alloc] init];
        [combinedContext addEntriesFromDictionary:internalContext];
        [combinedContext addEntriesFromDictionary:context];

        _context = [combinedContext copy];
        _integrations = [integrations copy];
        _channel = @"mobile";
        _messageId = nil;
        _userId = nil;
        _anonymousId = nil;
    }
    return self;
}

@end


@implementation YMApplicationLifecyclePayload
@end


@implementation YMRemoteNotificationPayload
@end


@implementation YMContinueUserActivityPayload
@end


@implementation YMOpenURLPayload
@end
