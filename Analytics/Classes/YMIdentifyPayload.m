//
//  YMIdentifyPayload.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMIdentifyPayload.h"

@implementation YMIdentifyPayload

- (instancetype)initWithUserId:(NSString *)userId
                   anonymousId:(NSString *)anonymousId
                        traits:(NSDictionary *)traits
                       context:(NSDictionary *)context
                  integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _traits = [traits copy];
        self.anonymousId = [anonymousId copy];
        self.userId = [userId copy];
    }
    return self;
}

@end
