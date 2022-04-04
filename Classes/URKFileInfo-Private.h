//
//  URKFileInfo-Private.h
//  UnrarKit
//

#import <Foundation/Foundation.h>
#import <UnrarKit/UnrarKitMacros.h>

RarosHppIgnore
#import <UnrarKit/raros.hpp>
#pragma clang diagnostic pop

DllHppIgnore
#import <UnrarKit/dll.hpp>
#pragma clang diagnostic pop

/**
 *  Private methods for URKFileInfo
 */
@interface URKFileInfo ()

/**
 *  The offset, in bytes, for this file header. Used for quick-seeking to the file info
 */
@property (readonly, assign, getter=getHeaderOffset) int64_t headerOffset;

/**
 *  Returns a URKFileInfo instance for the given extended header data
 *
 *  @param fileHeader The header data for a RAR file
 *
 *  @return an instance of URKFileInfo
 */
+ (instancetype) fileInfo:(struct RARHeaderDataEx *)fileHeader headerOffset:(int64_t)headerOffset;

@end
