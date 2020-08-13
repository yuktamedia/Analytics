//
//  YMCrypto.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>

@protocol YMCrypto <NSObject>

- (NSData *_Nullable)encrypt:(NSData *_Nonnull)data;
- (NSData *_Nullable)decrypt:(NSData *_Nonnull)data;

@end
