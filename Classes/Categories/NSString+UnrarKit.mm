//
//  NSString+UnrarKit.m
//  UnrarKit
//
//

#import "NSString+UnrarKit.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-align"
#pragma clang diagnostic ignored "-Wextra-semi"
#pragma clang diagnostic ignored "-Wold-style-cast"
#pragma clang diagnostic ignored "-Wpadded"
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wundef"
#import "rar.hpp"
#pragma clang diagnostic pop

@implementation NSString (UnrarKit)

+ (instancetype)stringWithUnichars:(wchar_t *)unichars {
    return [[NSString alloc] initWithBytes:unichars
                                    length:wcslen(unichars) * sizeof(*unichars)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}

@end
