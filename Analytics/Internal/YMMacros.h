//
//  YMMacros.h
//  Analytics
//
//  Created by Shrikant Patwari on 04/08/20.
//

#ifndef YMMacros_h
#define YMMacros_h

#import "TargetConditionals.h"

#define __deprecated__(s) __attribute__((deprecated(s)))

#define weakify(var) __weak typeof(var) __weak_##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = __weak_##var; \
_Pragma("clang diagnostic pop")

#if TARGET_OS_IOS == 1 || TARGET_OS_TV == 1
#define TARGET_UIKIT 1
#endif

#endif /* YMMacros_h */
