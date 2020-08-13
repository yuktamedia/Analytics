//
//  YMStoreKitTracker.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "YMAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(StoreKitTracker)
@interface YMStoreKitTracker : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)trackTransactionsForAnalytics:(YMAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END
