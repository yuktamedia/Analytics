//
//  YMHTTPClient.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMHTTPClient.h"
#import "NSData+YMGZIP.h"
#import "YMAnalyticsUtils.h"

static const NSUInteger kMaxBatchSize = 475000; // 475KB

@implementation YMHTTPClient

+ (NSMutableURLRequest * (^)(NSURL *))defaultRequestFactory
{
    return ^(NSURL *url) {
        return [NSMutableURLRequest requestWithURL:url];
    };
}

+ (NSString *)authorizationHeader:(NSString *)writeKey
{
    return [NSString stringWithFormat:@"Bearer %@", writeKey];
}


- (instancetype)initWithRequestFactory:(YMRequestFactory)requestFactory
{
    if (self = [self init]) {
        if (requestFactory == nil) {
            self.requestFactory = [YMHTTPClient defaultRequestFactory];
        } else {
            self.requestFactory = requestFactory;
        }
        _sessionsByWriteKey = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"Accept-Encoding" : @"gzip",
            @"User-Agent" : [NSString stringWithFormat:@"analytics-ios/%@", [YMAnalytics version]],
        };
        _genericSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (NSURLSession *)sessionForWriteKey:(NSString *)writeKey
{
    NSURLSession *session = self.sessionsByWriteKey[writeKey];
    if (!session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"Accept-Encoding" : @"gzip",
            @"Content-Encoding" : @"gzip",
            @"Content-Type" : @"application/json",
            @"Authorization" : [[self class] authorizationHeader:writeKey],
            @"User-Agent" : [NSString stringWithFormat:@"analytics-ios/%@", [YMAnalytics version]],
        };
        session = [NSURLSession sessionWithConfiguration:config delegate:self.httpSessionDelegate delegateQueue:NULL];
        self.sessionsByWriteKey[writeKey] = session;
    }
    return session;
}

- (void)dealloc
{
    for (NSURLSession *session in self.sessionsByWriteKey.allValues) {
        [session finishTasksAndInvalidate];
    }
    [self.genericSession finishTasksAndInvalidate];
}


- (nullable NSURLSessionUploadTask *)upload:(NSDictionary *)batch forWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL retry))completionHandler
{
    //    batch = YMCoerceDictionary(batch);
    NSURLSession *session = [self sessionForWriteKey:writeKey];

    NSURL *url = [YUKTAMEDIA_API_BASE URLByAppendingPathComponent:@"/datasync-android"];
    NSMutableURLRequest *request = self.requestFactory(url);

    // This is a workaround for an IOS 8.3 bug that causes Content-Type to be incorrectly set
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setHTTPMethod:@"POST"];

    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:batch options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        YMLog(@"Error serializing JSON for batch upload %@", error);
        completionHandler(NO); // Don't retry this batch.
        return nil;
    }
    if (payload.length >= kMaxBatchSize) {
        YMLog(@"Payload exceeded the limit of %luKB per batch", kMaxBatchSize / 1000);
        completionHandler(NO);
        return nil;
    }
    NSData *gzippedPayload = [payload ym_gzippedData];

    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:gzippedPayload completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            // Network error. Retry.
            YMLog(@"Error uploading request %@.", error);
            completionHandler(YES);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code < 300) {
            // 2xx response codes. Don't retry.
            completionHandler(NO);
            return;
        }
        if (code < 400) {
            // 3xx response codes. Retry.
            YMLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(YES);
            return;
        }
        if (code == 429) {
          // 429 response codes. Retry.
          YMLog(@"Server limited client with response code %d.", code);
          completionHandler(YES);
          return;
        }
        if (code < 500) {
            // non-429 4xx response codes. Don't retry.
            YMLog(@"Server rejected payload with HTTP code %d.", code);
            completionHandler(NO);
            return;
        }

        // 5xx response codes. Retry.
        YMLog(@"Server error with HTTP code %d.", code);
        completionHandler(YES);
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)settingsForWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable settings))completionHandler
{
    NSURLSession *session = self.genericSession;

    NSURL *url = [YUKTAMEDIA_CDN_BASE URLByAppendingPathComponent:[NSString stringWithFormat:@"/projects/settings?key=%@", writeKey]];
    NSMutableURLRequest *request = self.requestFactory(url);
    [request setHTTPMethod:@"GET"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error != nil) {
            YMLog(@"Error fetching settings %@.", error);
            completionHandler(NO, nil);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code > 300) {
            YMLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(NO, nil);
            return;
        }

        NSError *jsonError = nil;
        id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            YMLog(@"Error deserializing response body %@.", jsonError);
            completionHandler(NO, nil);
            return;
        }

        completionHandler(YES, responseJson);
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)attributionWithWriteKey:(NSString *)writeKey forDevice:(JSON_DICT)context completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable properties))completionHandler;

{
    NSURLSession *session = [self sessionForWriteKey:writeKey];

    NSURL *url = [MOBILE_SERVICE_BASE URLByAppendingPathComponent:@"/attribution"];
    NSMutableURLRequest *request = self.requestFactory(url);
    [request setHTTPMethod:@"POST"];

    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:context options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        YMLog(@"Error serializing context to JSON %@", error);
        completionHandler(NO, nil);
        return nil;
    }
    NSData *gzippedPayload = [payload ym_gzippedData];

    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:gzippedPayload completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            YMLog(@"Error making request %@.", error);
            completionHandler(NO, nil);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code > 300) {
            YMLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(NO, nil);
            return;
        }

        NSError *jsonError = nil;
        id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            YMLog(@"Error deserializing response body %@.", jsonError);
            completionHandler(NO, nil);
            return;
        }

        completionHandler(YES, responseJson);
    }];
    [task resume];
    return task;
}

@end
