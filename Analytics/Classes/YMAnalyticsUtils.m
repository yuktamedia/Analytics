//
//  YMAnalyticsUtils.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMAnalyticsUtils.h"

@implementation YMAnalyticsUtils

static BOOL kAnalyticsLoggerShowLogs = NO;

// Logging

void YMSetShowDebugLogs(BOOL showDebugLogs)
{
    kAnalyticsLoggerShowLogs = showDebugLogs;
}

void YMLog(NSString *format, ...)
{
    if (!kAnalyticsLoggerShowLogs)
        return;

    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
}

@end
