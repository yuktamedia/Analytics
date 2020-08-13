//
//  YMScreenPayload.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMPayload.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ScreenPayload)
@interface YMScreenPayload : YMPayload

@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly, nullable) NSString *category;

@property (nonatomic, readonly, nullable) NSDictionary *properties;

- (instancetype)initWithName:(NSString *)name
                  properties:(NSDictionary *_Nullable)properties
                     context:(NSDictionary *)context
                integrations:(NSDictionary *)integrations;

@end


NS_ASSUME_NONNULL_END
