//
//  YMIntegrationFactory.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMIntegration.h"
#import "YMAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

@class YMAnalytics;

@protocol YMIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<YMIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(YMAnalytics *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

NS_ASSUME_NONNULL_END
