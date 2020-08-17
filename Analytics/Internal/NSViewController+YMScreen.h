//
//  NSViewController+YMScreen.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#import <Foundation/Foundation.h>

#import "YMSerializableValue.h"

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>

@interface NSViewController (YMScreen)

+ (void)ym_swizzleViewDidAppear;
+ (void)ym_swizzleViewDidDisappear;
+ (NSViewController *)ym_rootViewControllerFromView:(NSView *)view;

@end

#endif
