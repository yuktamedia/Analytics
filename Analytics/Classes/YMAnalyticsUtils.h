//
//  YMAnalyticsUtils.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMAnalyticsUtils : NSObject

// Logging

void YMSetShowDebugLogs(BOOL showDebugLogs);
void YMLog(NSString *format, ...);

@end

NS_ASSUME_NONNULL_END
