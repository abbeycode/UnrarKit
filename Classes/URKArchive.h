//
//  URKArchive.h
//  UnrarKit
//
//

#import <Foundation/Foundation.h>
#import "raros.hpp"
#import "dll.hpp"

/**
 *  Defines the various error codes that the listing and extraction methods return.
 *  These are returned in NSError's [code]([NSError code]) field.
 */
typedef NS_ENUM(NSInteger, URKErrorCode) {

    /**
     *  The archive's header is empty
     */
    URKErrorCodeEndOfArchive = ERAR_END_ARCHIVE,
    
    /**
     *  The library ran out of memory while reading the archive
     */
    URKErrorCodeNoMemory = ERAR_NO_MEMORY,
    
    /**
     *  The header is broken
     */
    URKErrorCodeBadData = ERAR_BAD_DATA,
    
    /**
     *  The archive is not a valid RAR file
     */
    URKErrorCodeBadArchive = ERAR_BAD_ARCHIVE,
    
    /**
     *  The archive is an unsupported RAR format or version
     */
    URKErrorCodeUnknownFormat = ERAR_UNKNOWN_FORMAT,
    
    /**
     *  Failed to open a reference to the file
     */
    URKErrorCodeOpen = ERAR_EOPEN,
    
    /**
     *  Failed to create the target directory for extraction
     */
    URKErrorCodeCreate = ERAR_ECREATE,
    
    /**
     *  Failed to close the archive
     */
    URKErrorCodeClose = ERAR_ECLOSE,
    
    /**
     *  Failed to read the archive
     */
    URKErrorCodeRead = ERAR_EREAD,

    /**
     *  Failed to write a file to disk
     */
    URKErrorCodeWrite = ERAR_EWRITE,

    /**
     *  The archive header's comments are larger than the buffer size
     */
    URKErrorCodeSmall = ERAR_SMALL_BUF,

    /**
     *  The cause of the error is unspecified
     */
    URKErrorCodeUnknown = ERAR_UNKNOWN,

    /**
     *  A password was not given for a password-protected archive
     */
    URKErrorCodeMissingPassword = ERAR_MISSING_PASSWORD,

    /**
     *  No data was returned from the archive
     */
    URKErrorCodeArchiveNotFound = 101,
};

#define ERAR_ARCHIVE_NOT_FOUND  101

extern NSString *URKErrorDomain;

/**
 *  An Objective-C/Cocoa wrapper around the unrar library
 */
@interface URKArchive : NSObject {

	HANDLE _rarFile;
	struct RARHeaderDataEx *header;
	struct RAROpenArchiveDataEx *flags;
}


/**
 *  The filename of the archive
 */
@property(nonatomic, retain) NSString *filename;

/**
 *  The password of the archive
 */
@property(nonatomic, retain) NSString *password;


/**
 *  Creates and returns an archive at the given path
 *
 *  @param filePath A path to the archive file
 */
+ (instancetype)rarArchiveAtPath:(NSString *)filePath;

/**
 *  Creates and returns an archive at the given URL
 *
 *  @param fileURL The URL of the archive file
 */
+ (instancetype)rarArchiveAtURL:(NSURL *)fileURL;

/**
 *  Creates and returns an archive at the given path, with a given password
 *
 *  @param filePath A path to the archive file
 *  @param password The passowrd of the given archive
 */
+ (instancetype)rarArchiveAtPath:(NSString *)filePath password:(NSString *)password;

/**
 *  Creates and returns an archive at the given URL, with a given password
 *
 *  @param fileURL  The URL of the archive file
 *  @param password The passowrd of the given archive
 */
+ (instancetype)rarArchiveAtURL:(NSURL *)fileURL password:(NSString *)password;


/**
 *  Lists the files in the archive
 *
 *  @param error Contains an NSError object when there was an error reading the archive
 *
 *  @return Returns a list of NSString containing the paths within the archive's contents, or nil if an error was encountered
 */
- (NSArray *)listFiles:(NSError **)error;

/**
 *  Writes all files in the archive to the given path
 *
 *  @param filePath  The destination path of the unarchived files
 *  @param overwrite YES to overwrite files in the destination directory, NO otherwise
 *  @param error     Contains an NSError object when there was an error reading the archive
 *
 *  @return YES on successful extraction, NO if an error was encountered
 */
- (BOOL)extractFilesTo:(NSString *)filePath overWrite:(BOOL)overwrite error:(NSError **)error;

/**
 *  Unarchive a single file from the archive into memory
 *
 *  @param filePath The path of the file within the archive to be expanded
 *  @param error    Contains an NSError object when there was an error reading the archive
 *
 *  @return An NSData object containing the bytes of the file, or nil if an error was encountered
 */
- (NSData *)extractDataFromFile:(NSString *)filePath error:(NSError **)error;

@end
