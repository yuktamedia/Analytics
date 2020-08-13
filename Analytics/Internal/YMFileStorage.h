//
//  YMFileStorage.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMStorage.h"


NS_SWIFT_NAME(FileStorage)
@interface YMFileStorage : NSObject <YMStorage>

@property (nonatomic, strong, nullable) id<YMCrypto> crypto;

- (instancetype _Nonnull)initWithFolder:(NSURL *_Nonnull)folderURL crypto:(id<YMCrypto> _Nullable)crypto;

- (NSURL *_Nonnull)urlForKey:(NSString *_Nonnull)key;

+ (NSURL *_Nullable)applicationSupportDirectoryURL;
+ (NSURL *_Nullable)cachesDirectoryURL;

@end
