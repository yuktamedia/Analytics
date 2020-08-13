//
//  YMStorage.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import "YMCrypto.h"

@protocol YMStorage <NSObject>

@property (nonatomic, strong, nullable) id<YMCrypto> crypto;

- (void)removeKey:(NSString *_Nonnull)key;
- (void)resetAll;

- (void)setData:(NSData *_Nullable)data forKey:(NSString *_Nonnull)key;
- (NSData *_Nullable)dataForKey:(NSString *_Nonnull)key;

- (void)setDictionary:(NSDictionary *_Nullable)dictionary forKey:(NSString *_Nonnull)key;
- (NSDictionary *_Nullable)dictionaryForKey:(NSString *_Nonnull)key;

- (void)setArray:(NSArray *_Nullable)array forKey:(NSString *_Nonnull)key;
- (NSArray *_Nullable)arrayForKey:(NSString *_Nonnull)key;

- (void)setString:(NSString *_Nullable)string forKey:(NSString *_Nonnull)key;
- (NSString *_Nullable)stringForKey:(NSString *_Nonnull)key;

// Number and Booleans are intentionally omitted at the moment because they are not needed

@end
