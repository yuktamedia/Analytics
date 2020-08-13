//
//  YMTrackPayload.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMTrackPayload.h"


@implementation YMTrackPayload


- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _event = [event copy];
        _properties = [properties copy];
    }
    return self;
}

@end
