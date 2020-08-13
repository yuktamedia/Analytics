//
//  YMIntegrationsManager.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMMiddleware.h"

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *_Nonnull const kYMAnonymousIdFilename;
extern NSString *_Nonnull const kYMCachedSettingsFilename;

/**
 * NSNotification name, that is posted after integrations are loaded.
 */
extern NSString *_Nonnull YMAnalyticsIntegrationDidStart;

@class YMAnalytics;

NS_SWIFT_NAME(IntegrationsManager)
@interface YMIntegrationsManager : NSObject

// Exposed for testing.
+ (BOOL)isIntegration:(NSString *_Nonnull)key enabledInOptions:(NSDictionary *_Nonnull)options;
+ (BOOL)isTrackEvent:(NSString *_Nonnull)event enabledForIntegration:(NSString *_Nonnull)key inPlan:(NSDictionary *_Nonnull)plan;

// @Deprecated - Exposing for backward API compat reasons only
@property (nonatomic, readonly) NSMutableDictionary *_Nonnull registeredIntegrations;

- (instancetype _Nonnull)initWithAnalytics:(YMAnalytics *_Nonnull)analytics;

// @Deprecated - Exposing for backward API compat reasons only
- (NSString *_Nonnull)getAnonymousId;

@end


@interface YMIntegrationsManager (YMMiddleware) <YMMiddleware>

@end
