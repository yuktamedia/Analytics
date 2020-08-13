//
//  YMUtils.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMAnalyticsUtils.h"
#import "YMSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN

@class YMAnalyticsConfiguration;
@class YMReachability;

NS_SWIFT_NAME(Utilities)
@interface YMUtils : NSObject

+ (NSData *_Nullable)dataFromPlist:(nonnull id)plist;
+ (id _Nullable)plistFromData:(NSData *)data;

+ (id _Nullable)traverseJSON:(id _Nullable)object andReplaceWithFilters:(NSDictionary<NSString*, NSString*>*)patterns;

@end

BOOL isUnitTesting(void);

NSString * _Nullable deviceTokenToString(NSData * _Nullable deviceToken);
NSString *getDeviceModel(void);
BOOL getAdTrackingEnabled(YMAnalyticsConfiguration *configuration);
NSDictionary *getStaticContext(YMAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
NSDictionary *getLiveContext(YMReachability *reachability, NSDictionary * _Nullable referrer, NSDictionary * _Nullable traits);

NSString *GenerateUUIDString(void);

#if TARGET_OS_IPHONE
NSDictionary *mobileSpecifications(YMAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
#elif TARGET_OS_OSX
NSDictionary *desktopSpecifications(YMAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
#endif

// Date Utils
NSString *iso8601FormattedString(NSDate *date);
NSString *iso8601NanoFormattedString(NSDate *date);

void trimQueue(NSMutableArray *array, NSUInteger size);

// Async Utils
dispatch_queue_t ym_dispatch_queue_create_specific(const char *label,
                                                    dispatch_queue_attr_t _Nullable attr);
BOOL ym_dispatch_is_on_specific_queue(dispatch_queue_t queue);
void ym_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion);
void ym_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block);
void ym_dispatch_specific_sync(dispatch_queue_t queue, dispatch_block_t block);

// JSON Utils

JSON_DICT YMCoerceDictionary(NSDictionary *_Nullable dict);

NSString *_Nullable YMIDFA(void);

NSString *YMEventNameForScreenTitle(NSString *title);

// Deep copy and check NSCoding conformance
@protocol YMSerializableDeepCopy <NSObject>
-(id _Nullable) serializableMutableDeepCopy;
-(id _Nullable) serializableDeepCopy;
@end

@interface NSDictionary(SerializableDeepCopy) <YMSerializableDeepCopy>
@end

@interface NSArray(SerializableDeepCopy) <YMSerializableDeepCopy>
@end


NS_ASSUME_NONNULL_END
