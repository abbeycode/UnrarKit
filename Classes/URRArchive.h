//
//  URRArchive.h
//  Unrar4iOS
//
//  Created by Dov Frankel on 03/21/2014.
//  Copyright 2014 Abbey Code. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "raros.hpp"
#import "dll.hpp"

typedef NS_ENUM(NSInteger, URRErrorCode) {
    URRErrorCodeEndOfArchive    = ERAR_END_ARCHIVE,
    URRErrorCodeNoMemory        = ERAR_NO_MEMORY,
    URRErrorCodeBadData         = ERAR_BAD_DATA,
    URRErrorCodeBadArchive      = ERAR_BAD_ARCHIVE,
    URRErrorCodeUnknownFormat   = ERAR_UNKNOWN_FORMAT,
    URRErrorCodeOpen            = ERAR_EOPEN,
    URRErrorCodeCreate          = ERAR_ECREATE,
    URRErrorCodeClose           = ERAR_ECLOSE,
    URRErrorCodeRead            = ERAR_EREAD,
    URRErrorCodeWrite           = ERAR_EWRITE,
    URRErrorCodeSmall           = ERAR_SMALL_BUF,
    URRErrorCodeUnknown         = ERAR_UNKNOWN,
    URRErrorCodeMissingPassword = ERAR_MISSING_PASSWORD,
    URRErrorCodeArchiveNotFound = 101,
};

#define ERAR_ARCHIVE_NOT_FOUND  101

extern NSString *URRErrorDomain;

@interface URRArchive : NSObject {

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
