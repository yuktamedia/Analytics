//
//  YMScreenPayload.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMScreenPayload.h"


@implementation YMScreenPayload

- (instancetype)initWithName:(NSString *)name
                  properties:(NSDictionary *)properties
                     context:(NSDictionary *)context
                integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _name = [name copy];
        _properties = [properties copy];
    }
    return self;
}

@end
