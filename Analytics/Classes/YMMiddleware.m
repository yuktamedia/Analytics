//
//  YMMiddleware.m
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import "YMUtils.h"
#import "YMMiddleware.h"


@implementation YMDestinationMiddleware
- (instancetype)initWithKey:(NSString *)integrationKey middleware:(NSArray<id<YMMiddleware>> *)middleware
{
    if (self = [super init]) {
        _integrationKey = integrationKey;
        _middleware = middleware;
    }
    return self;
}
@end

@implementation YMBlockMiddleware

- (instancetype)initWithBlock:(YMMiddlewareBlock)block
{
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (void)context:(YMContext *)context next:(YMMiddlewareNext)next
{
    self.block(context, next);
}

@end


@implementation YMMiddlewareRunner

- (instancetype)initWithMiddleware:(NSArray<id<YMMiddleware>> *_Nonnull)middlewares
{
    if (self = [super init]) {
        _middlewares = middlewares;
    }
    return self;
}

- (YMContext *)run:(YMContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback
{
    return [self runMiddlewares:self.middlewares context:context callback:callback];
}

// TODO: Maybe rename YMContext to YMEvent to be a bit more clear?
// We could also use some sanity check / other types of logging here.
- (YMContext *)runMiddlewares:(NSArray<id<YMMiddleware>> *_Nonnull)middlewares
               context:(YMContext *_Nonnull)context
              callback:(RunMiddlewaresCallback _Nullable)callback
{
    __block YMContext * _Nonnull result = context;

    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return context;
    }
    
    [middlewares[0] context:result next:^(YMContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        result = [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
    
    return result;
}

@end
