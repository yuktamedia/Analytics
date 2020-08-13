//
//  UIViewController+YMScreen.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//
#import "YMSerializableValue.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface UIViewController (YMScreen)

+ (void)ym_swizzleViewDidAppear;
+ (UIViewController *)ym_rootViewControllerFromView:(UIView *)view;

@end

#endif
