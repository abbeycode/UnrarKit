//
//  UnrarKitMacros.h
//  UnrarKit
//
//  Created by Dov Frankel on 8/8/17.
//  Copyright © 2017 Abbey Code. All rights reserved.
//

#ifndef UnrarKitMacros_h
#define UnrarKitMacros_h

//#import "Availability.h"
//#import "AvailabilityInternal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#pragma clang diagnostic ignored "-Wgnu-zero-variadic-macro-arguments"


// iOS 10, macOS 10.12, tvOS 10.0, watchOS 3.0
#define UNIFIED_LOGGING_SUPPORTED \
__IPHONE_OS_VERSION_MIN_REQUIRED >= 100000 \
|| __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200 \
|| __TV_OS_VERSION_MIN_REQUIRED >= 100000 \
|| __WATCH_OS_VERSION_MIN_REQUIRED >= 30000

#if UNIFIED_LOGGING_SUPPORTED
#import <os/log.h>

// Called from +[UnrarKit initialize] and +[URKArchiveTestCase setUp]
extern os_log_t unrarkit_log; // Declared in URKArchive.m
#define URKLogInit() unrarkit_log = os_log_create("com.abbey-code.UnrarKit", "General");

#define URKLog(format, ...)      os_log(unrarkit_log, format, ##__VA_ARGS__);
#define URKLogInfo(format, ...)  os_log_info(unrarkit_log, format, ##__VA_ARGS__);
#define URKLogDebug(format, ...) os_log_debug(unrarkit_log, format, ##__VA_ARGS__);

#define URKLogError(format, ...) os_log_error(unrarkit_log, format, ##__VA_ARGS__);
#define URKLogFault(format, ...) os_log_fault(unrarkit_log, format, ##__VA_ARGS__);

#define URKCreateActivity(name) \
os_activity_t activity = os_activity_create(name, OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT); \
os_activity_scope(activity);


#else // Fall back to regular NSLog

// No-op, as nothing needs to be initialized
#define URKLogInit() (void)0


// Only used below
#define _removeLogFormatTokens(format) [@format stringByReplacingOccurrencesOfString:@"{public}" withString:@""]
#define _stringify(a) #a
#define _nsLogWithoutWarnings(format, ...) \
_Pragma( _stringify( clang diagnostic push ) ) \
_Pragma( _stringify( clang diagnostic ignored "-Wformat-nonliteral" ) ) \
_Pragma( _stringify( clang diagnostic ignored "-Wformat-security" ) ) \
NSLog(_removeLogFormatTokens(format), ##__VA_ARGS__); \
_Pragma( _stringify( clang diagnostic pop ) )

// All levels do the same thing
#define URKLog(format, ...)      _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define URKLogInfo(format, ...)  _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define URKLogDebug(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define URKLogError(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define URKLogFault(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);

// No-op, as no equivalent to Activities exists
#define URKCreateActivity(name) (void)0

#endif


#pragma clang diagnostic pop

#endif /* UnrarKitMacros_h */
