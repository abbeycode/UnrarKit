//
//  URKArchive.h
//  UnrarKit
//
//

#import <Foundation/Foundation.h>
#import "raros.hpp"
#import "dll.hpp"

typedef NS_ENUM(NSInteger, URKErrorCode) {
    URKErrorCodeEndOfArchive    = ERAR_END_ARCHIVE,
    URKErrorCodeNoMemory        = ERAR_NO_MEMORY,
    URKErrorCodeBadData         = ERAR_BAD_DATA,
    URKErrorCodeBadArchive      = ERAR_BAD_ARCHIVE,
    URKErrorCodeUnknownFormat   = ERAR_UNKNOWN_FORMAT,
    URKErrorCodeOpen            = ERAR_EOPEN,
    URKErrorCodeCreate          = ERAR_ECREATE,
    URKErrorCodeClose           = ERAR_ECLOSE,
    URKErrorCodeRead            = ERAR_EREAD,
    URKErrorCodeWrite           = ERAR_EWRITE,
    URKErrorCodeSmall           = ERAR_SMALL_BUF,
    URKErrorCodeUnknown         = ERAR_UNKNOWN,
    URKErrorCodeMissingPassword = ERAR_MISSING_PASSWORD,
    URKErrorCodeArchiveNotFound = 101,
};

#define ERAR_ARCHIVE_NOT_FOUND  101

extern NSString *URKErrorDomain;

@interface URKArchive : NSObject {

	HANDLE _rarFile;
	struct RARHeaderDataEx *header;
	struct RAROpenArchiveDataEx *flags;
}

@property(nonatomic, retain) NSString *filename;
@property(nonatomic, retain) NSString *password;

+ (instancetype)rarArchiveAtPath:(NSString *)filePath;
+ (instancetype)rarArchiveAtURL:(NSURL *)fileURL;
+ (instancetype)rarArchiveAtPath:(NSString *)filePath password:(NSString *)password;
+ (instancetype)rarArchiveAtURL:(NSURL *)fileURL password:(NSString *)password;

- (NSArray *)listFiles:(NSError **)error;
- (BOOL)extractFilesTo:(NSString *)filePath overWrite:(BOOL)overwrite error:(NSError **)error;
- (NSData *)extractDataFromFile:(NSString *)filePath error:(NSError **)error;

- (BOOL)closeFile;

@end
