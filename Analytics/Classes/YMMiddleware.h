//
//  YMMiddleware.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMContext.h"

typedef void (^YMMiddlewareNext)(YMContext *_Nullable newContext);

NS_SWIFT_NAME(Middleware)
@protocol YMMiddleware
@required

// NOTE: If you want to hold onto references of context AFTER passing it through to the next
// middleware, you should explicitly create a copy via `[context copy]` to guarantee
// that it does not get changed from underneath you because contexts can be implemented
// as mutable objects under the hood for performance optimization.
// The behavior of keeping reference to a context AFTER passing it to the next middleware
// is strictly undefined.

// Middleware should **always** call `next`. If the intention is to explicitly filter out
// events from downstream, call `next` with `nil` as the param.
// It's ok to save next callback until a more convenient time, but it should always always be done.
// We'll probably actually add tests to sure it is so.
// TODO: Should we add error as second param to next?
- (void)context:(YMContext *_Nonnull)context next:(YMMiddlewareNext _Nonnull)next;

@end

typedef void (^YMMiddlewareBlock)(YMContext *_Nonnull context, YMMiddlewareNext _Nonnull next);


NS_SWIFT_NAME(BlockMiddleware)
@interface YMBlockMiddleware : NSObject <YMMiddleware>

@property (nonnull, nonatomic, readonly) YMMiddlewareBlock block;

- (instancetype _Nonnull)initWithBlock:(YMMiddlewareBlock _Nonnull)block;

@end


typedef void (^RunMiddlewaresCallback)(BOOL earlyExit, NSArray<id<YMMiddleware>> *_Nonnull remainingMiddlewares);

// XXX TODO: Add some tests for YMMiddlewareRunner
NS_SWIFT_NAME(MiddlewareRunner)
@interface YMMiddlewareRunner : NSObject

// While it is certainly technically possible to change middlewares dynamically on the fly. we're explicitly NOT
// gonna support that for now to keep things simple. If there is a real need later we'll see then.
@property (nonnull, nonatomic, readonly) NSArray<id<YMMiddleware>> *middlewares;

- (YMContext * _Nonnull)run:(YMContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback;

- (instancetype _Nonnull)initWithMiddleware:(NSArray<id<YMMiddleware>> *_Nonnull)middlewares;

@end

// Container object for middlewares for a specific destination.
NS_SWIFT_NAME(DestinationMiddleware)
@interface YMDestinationMiddleware : NSObject
@property (nonatomic, strong, nonnull, readonly) NSString *integrationKey;
@property (nonatomic, strong, nullable, readonly) NSArray<id<YMMiddleware>> *middleware;
- (instancetype _Nonnull)initWithKey:(NSString * _Nonnull)integrationKey middleware:(NSArray<id<YMMiddleware>> * _Nonnull)middleware;
@end
