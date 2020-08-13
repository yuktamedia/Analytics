//
//  YMUserDefaultsStorage.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMStorage.h"


NS_SWIFT_NAME(UserDefaultsStorage)
@interface YMUserDefaultsStorage : NSObject <YMStorage>

@property (nonatomic, strong, nullable) id<YMCrypto> crypto;
@property (nonnull, nonatomic, readonly) NSUserDefaults *defaults;
@property (nullable, nonatomic, readonly) NSString *namespacePrefix;

- (instancetype _Nonnull)initWithDefaults:(NSUserDefaults *_Nonnull)defaults namespacePrefix:(NSString *_Nullable)namespacePrefix crypto:(id<YMCrypto> _Nullable)crypto;

@end
