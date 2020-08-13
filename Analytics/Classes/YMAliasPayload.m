//
//  YMAliasPayload.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMAliasPayload.h"


@implementation YMAliasPayload

- (instancetype)initWithNewId:(NSString *)newId
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _theNewId = [newId copy];
    }
    return self;
}

@end
