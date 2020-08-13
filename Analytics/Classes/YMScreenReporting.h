//
//  YMScreenReporting.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#import "YMSerializableValue.h"

/** Implement this protocol to override automatic screen reporting */

NS_ASSUME_NONNULL_BEGIN

@protocol YMScreenReporting <NSObject>

@optional
#if TARGET_OS_IPHONE
- (void)ym_trackScreen:(UIViewController*)screen name:(NSString*)name;
@property (readonly, nullable) UIViewController *ym_mainViewController;
#elif TARGET_OS_OSX
- (void)ym_trackScreen:(NSViewController*)screen name:(NSString*)name;
@property (readonly, nullable) NSViewController *ym_mainViewController;
#endif

@end

NS_ASSUME_NONNULL_END
