//
//  YMTrackPayload.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMPayload.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(TrackPayload)
@interface YMTrackPayload : YMPayload

@property (nonatomic, readonly) NSString *event;

@property (nonatomic, readonly, nullable) NSDictionary *properties;

- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *_Nullable)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

NS_ASSUME_NONNULL_END
