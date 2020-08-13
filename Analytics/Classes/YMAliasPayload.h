//
//  YMAliasPayload.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMPayload.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AliasPayload)
@interface YMAliasPayload : YMPayload

@property (nonatomic, readonly) NSString *theNewId;

- (instancetype)initWithNewId:(NSString *)newId
                      context:(JSON_DICT)context
                 integrations:(JSON_DICT)integrations;

@end

NS_ASSUME_NONNULL_END
