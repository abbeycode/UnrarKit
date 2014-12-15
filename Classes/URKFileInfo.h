//
//  URKFileInfo.h
//  UnrarKit
//

#import <Foundation/Foundation.h>
#import "raros.hpp"
#import "dll.hpp"

/* See http://www.forensicswiki.org/wiki/RAR and
   http://www.rarlab.com/technote.htm#filehead for
   more information about the RAR File Header spec */

typedef NS_OPTIONS(NSUInteger, URKFileFlags) {
    URKFileFlagsFileContinuedFromPreviousVolume = 1 << 0,
    URKFileFlagsFileContinuedOnNextVolume       = 1 << 1,
    URKFileFlagsFileEncryptedWithPassword       = 1 << 2,
    URKFileFlagsFileCommentPresent              = 1 << 3,
};

typedef NS_ENUM(NSUInteger, URKFilePackingMethod) {
    URKFilePackingMethodStorage            = 0x30,
    URKFilePackingMethodFastestCompression = 0x31,
    URKFilePackingMethodFastCompression    = 0x32,
    URKFilePackingMethodNormalCompression  = 0x33,
    URKFilePackingMethodGoodCompression    = 0x34,
    URKFIlePackingMethodBestCompression    = 0x35,
};

typedef NS_ENUM(NSUInteger, URKFileHostOS) {
    URKFileHostOSMSDOS   = 0,
    URKFileHostOSOS2     = 1,
    URKFileHostOSWindows = 2,
    URKFileHostOSUnix    = 3,
    URKFileHostOSMacOS   = 4,
    URKFileHostOSBeOS    = 5,
};

@interface URKFileInfo : NSObject

@property (nonatomic, strong) NSString *archiveName;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSDate *fileTime;
@property (nonatomic, assign) NSUInteger fileCRC;
@property (nonatomic, assign) NSUInteger fileDictionary;
@property (nonatomic, assign) long long unpackedSize;
@property (nonatomic, assign) long long packedSize;
@property (nonatomic, assign) URKFileFlags flags;
@property (nonatomic, assign) URKFilePackingMethod packingMethod;
@property (nonatomic, assign) URKFileHostOS hostOS;

- (instancetype)initWithFileHeader:(struct RARHeaderDataEx *)fileHeader;

@end
