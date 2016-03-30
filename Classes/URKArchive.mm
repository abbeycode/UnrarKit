//
//  URKArchive.mm
//  UnrarKit
//
//

#import "URKArchive.h"
#import "URKFileInfo.h"
#import "NSString+UnrarKit.h"

#import "rar.hpp"


NSString *URKErrorDomain = @"URKErrorDomain";


@interface URKArchive ()

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError **)error
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_0 || MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
NS_DESIGNATED_INITIALIZER
#endif
;

@property (strong) NSData *fileBookmark;
@property (strong) void(^bufferedReadBlock)(NSData *dataChunk);

@property (strong) NSObject *threadLock;

@end


@implementation URKArchive



#pragma mark - Deprecated Convenience Methods


+ (URKArchive *)rarArchiveAtPath:(NSString *)filePath
{
    return [[URKArchive alloc] initWithPath:filePath error:nil];
}

+ (URKArchive *)rarArchiveAtURL:(NSURL *)fileURL
{
    return [[URKArchive alloc] initWithURL:fileURL error:nil];
}

+ (URKArchive *)rarArchiveAtPath:(NSString *)filePath password:(NSString *)password
{
    return [[URKArchive alloc] initWithPath:filePath password:password error:nil];
}

+ (URKArchive *)rarArchiveAtURL:(NSURL *)fileURL password:(NSString *)password
{
    return [[URKArchive alloc] initWithURL:fileURL password:password error:nil];
}



#pragma mark - Initializers


- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class URKArchive"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initWithPath:(NSString *)filePath error:(NSError **)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath] error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)error
{
    return [self initWithFile:fileURL error:error];
}

- (instancetype)initWithPath:(NSString *)filePath password:(NSString *)password error:(NSError **)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath] password:password error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL password:(NSString *)password error:(NSError **)error
{
    return [self initWithFile:fileURL password:password error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL error:(NSError **)error
{
    return [self initWithFile:fileURL password:nil error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError **)error
{
    if (!fileURL) {
        return nil;
    }

    if ((self = [super init])) {
        if (error) {
            *error = nil;
        }

        NSError *bookmarkError = nil;
        _fileBookmark = [fileURL bookmarkDataWithOptions:0
                          includingResourceValuesForKeys:@[]
                                           relativeToURL:nil
                                                   error:&bookmarkError];
        _password = password;
        _threadLock = [[NSObject alloc] init];

        if (bookmarkError) {
            NSLog(@"Error creating bookmark to RAR archive: %@", bookmarkError);

            if (error) {
                *error = bookmarkError;
            }

            return nil;
        }
    }

    return self;
}


#pragma mark - Properties


- (NSURL *)fileURL
{
    BOOL bookmarkIsStale = NO;
    NSError *error = nil;

    NSURL *result = [NSURL URLByResolvingBookmarkData:self.fileBookmark
                                              options:0
                                        relativeToURL:nil
                                  bookmarkDataIsStale:&bookmarkIsStale
                                                error:&error];

    if (error) {
        NSLog(@"Error resolving bookmark to RAR archive: %@", error);
        return nil;
    }

    if (bookmarkIsStale) {
        self.fileBookmark = [result bookmarkDataWithOptions:0
                             includingResourceValuesForKeys:@[]
                                              relativeToURL:nil
                                                      error:&error];

        if (error) {
            NSLog(@"Error creating fresh bookmark to RAR archive: %@", error);
        }
  }

    return result;
}

- (NSString *)filename
{
    NSURL *url = self.fileURL;

    if (!url) {
        return nil;
    }

    return url.path;
}

- (NSNumber *)uncompressedSize
{
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo) {
        NSLog(@"Error getting uncompressed size: %@", listError);
        return nil;
    }
    
    if (fileInfo.count == 0) {
        return 0;
    }
        
    return [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
}

- (NSNumber *)compressedSize
{
    NSString *filePath = self.filename;
    
    if (!filePath) {
        NSLog(@"Can't get compressed size, since a file path can't be resolved");
        return nil;
    }
    
    NSError *attributesError = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath
                                                                                error:&attributesError];
    
    if (!attributes) {
        NSLog(@"Error getting compressed size of %@: %@", filePath, attributesError);
        return nil;
    }
    
    return [NSNumber numberWithUnsignedLongLong:attributes.fileSize];
}



#pragma mark - Zip file detection


+ (BOOL)pathIsARAR:(NSString *)filePath
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];

    if (!handle) {
        return NO;
    }

    @try {
        NSData *fileData = [handle readDataOfLength:8];

        if (fileData.length < 8) {
            return NO;
        }

        const unsigned char *dataBytes = (const unsigned char *)fileData.bytes;

        // Check the magic numbers for all versions (Rar!..)
        if (dataBytes[0] != 0x52 ||
            dataBytes[1] != 0x61 ||
            dataBytes[2] != 0x72 ||
            dataBytes[3] != 0x21 ||
            dataBytes[4] != 0x1A ||
            dataBytes[5] != 0x07) {
            return NO;
        }

        // Check for v1.5 and on
        if (dataBytes[6] == 0x00) {
            return YES;
        }

        // Check for v5.0
        if (dataBytes[6] == 0x01 &&
            dataBytes[7] == 0x00) {
            return YES;
        }
    }
    @finally {
        [handle closeFile];
    }

    return NO;
}

+ (BOOL)urlIsARAR:(NSURL *)fileURL
{
    if (!fileURL || !fileURL.path) {
        return NO;
    }

    return [URKArchive pathIsARAR:fileURL.path];
}



#pragma mark - Public Methods


- (NSArray<NSString*> *)listFilenames:(NSError **)error
{
    NSArray *files = [self listFileInfo:error];
    return [files valueForKey:@"filename"];
}

- (NSArray<URKFileInfo*> *)listFileInfo:(NSError **)error
{
    __block NSMutableArray *fileInfos = [NSMutableArray array];

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;

        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
            [fileInfos addObject:[URKFileInfo fileInfo:header]];

            if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                [self assignError:error code:(NSInteger)PFCode];
                fileInfos = nil;
                return;
            }
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            [self assignError:error code:RHCode];
            fileInfos = nil;
        }
    } inMode:RAR_OM_LIST_INCSPLIT error:error];

	if (!success || !fileInfos) {
        return nil;
    }

    return [NSArray arrayWithArray:fileInfos];
}

- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
              progress:(void (^)(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed))progress
                 error:(NSError **)error
{
    __block BOOL result = YES;

    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];

    if (!fileInfo || listError) {
        NSLog(@"Error listing contents of archive: %@", listError);

        if (error) {
            *error = listError;
        }

        return NO;
    }

    NSNumber *totalSize = [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
    __block long long bytesDecompressed = 0;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            fileInfo = [URKFileInfo fileInfo:header];

            if (progress) {
                progress(fileInfo, bytesDecompressed / totalSize.floatValue);
            }

            if ([self headerContainsErrors:error]) {
                result = NO;
                return;
            }

            if ((PFCode = RARProcessFile(_rarFile, RAR_EXTRACT, (char *) filePath.UTF8String, NULL)) != 0) {
                [self assignError:error code:(NSInteger)PFCode];
                result = NO;
                return;
            }

            bytesDecompressed += fileInfo.uncompressedSize;
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            [self assignError:error code:RHCode];
            result = NO;
        }

        if (progress) {
            progress(fileInfo, 1.0);
        }

    } inMode:RAR_OM_EXTRACT error:error];

    return success && result;
}

- (NSData *)extractData:(URKFileInfo *)fileInfo
               progress:(void (^)(CGFloat percentDecompressed))progress
                  error:(NSError **)error
{
    return [self extractDataFromFile:fileInfo.filename progress:progress error:error];
}

- (NSData *)extractDataFromFile:(NSString *)filePath
                       progress:(void (^)(CGFloat percentDecompressed))progress
                          error:(NSError **)error
{
    __block NSData *result = nil;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            if ([self headerContainsErrors:error]) {
                return;
            }

            fileInfo = [URKFileInfo fileInfo:header];

            if ([fileInfo.filename isEqualToString:filePath]) {
                break;
            }
            else {
                if ((PFCode = RARProcessFileW(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                    [self assignError:error code:(NSInteger)PFCode];
                    return;
                }
            }
        }

        if (RHCode != ERAR_SUCCESS) {
            [self assignError:error code:RHCode];
            return;
        }

        // Empty file, or a directory
        if (fileInfo.uncompressedSize == 0) {
            result = [NSData data];
            return;
        }

        NSMutableData *fileData = [NSMutableData dataWithCapacity:(NSUInteger)fileInfo.uncompressedSize];
        CGFloat totalBytes = fileInfo.uncompressedSize;
        __block long long bytesRead = 0;

        if (progress) {
            progress(0.0);
        }

        RARSetCallback(_rarFile, BufferedReadCallbackProc, (long)(__bridge void *) self);
        self.bufferedReadBlock = ^void(NSData *dataChunk) {
            [fileData appendData:dataChunk];

            bytesRead += dataChunk.length;

            if (progress) {
                progress(bytesRead / totalBytes);
            }
        };

        PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

        if (PFCode != 0) {
            [self assignError:error code:(NSInteger)PFCode];
            return;
        }

        result = [NSData dataWithData:fileData];
    } inMode:RAR_OM_EXTRACT error:error];

    if (!success) {
        return nil;
    }

    return result;
}

- (BOOL)performOnFilesInArchive:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                          error:(NSError **)error
{
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];

    if (listError || !fileInfo) {
        NSLog(@"Failed to list the files in the archive");

        if (error) {
            *error = listError;
        }

        return NO;
    }

    NSArray *sortedFileInfo = [fileInfo sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES]]];

    [sortedFileInfo enumerateObjectsUsingBlock:^(URKFileInfo *info, NSUInteger idx, BOOL *stop) {
        action(info, stop);
    }];

    return YES;
}

- (BOOL)performOnDataInArchive:(void (^)(URKFileInfo *, NSData *, BOOL *))action
                         error:(NSError **)error
{
    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;

        BOOL stop = NO;

        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
            if (stop || [self headerContainsErrors:error]) {
                return;
            }

            URKFileInfo *info = [URKFileInfo fileInfo:header];

            // Empty file, or a directory
            if (info.uncompressedSize == 0) {
                action(info, [NSData data], &stop);
                continue;
            }

            UInt8 *buffer = (UInt8 *)malloc((size_t)info.uncompressedSize * sizeof(UInt8));
            UInt8 *callBackBuffer = buffer;

            RARSetCallback(_rarFile, CallbackProc, (long) &callBackBuffer);

            PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

            if (PFCode != 0) {
                [self assignError:error code:(NSInteger)PFCode];
                return;
            }

            NSData *data = [NSData dataWithBytesNoCopy:buffer length:(NSUInteger)info.uncompressedSize freeWhenDone:YES];
            action(info, data, &stop);
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            [self assignError:error code:RHCode];
            return;
        }
    } inMode:RAR_OM_EXTRACT error:error];

    return success;
}

- (BOOL)extractBufferedDataFromFile:(NSString *)filePath
                              error:(NSError **)error
                             action:(void(^)(NSData *dataChunk, CGFloat percentDecompressed))action
{
    NSError *innerError = nil;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            if ([self headerContainsErrors:error]) {
                return;
            }

            fileInfo = [URKFileInfo fileInfo:header];

            if ([fileInfo.filename isEqualToString:filePath]) {
                break;
            }
            else {
                if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                    [self assignError:error code:(NSInteger)PFCode];
                    return;
                }
            }
        }

        if (RHCode != ERAR_SUCCESS) {
            [self assignError:error code:RHCode];
            return;
        }

        // Empty file, or a directory
        if (fileInfo.uncompressedSize == 0) {
            return;
        }

        CGFloat totalBytes = fileInfo.uncompressedSize;
        __block long long bytesRead = 0;

        RARSetCallback(_rarFile, BufferedReadCallbackProc, (long)(__bridge void *) self);
        self.bufferedReadBlock = ^void(NSData *dataChunk) {
            bytesRead += dataChunk.length;
            action(dataChunk, bytesRead / totalBytes);
        };

        PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

        if (PFCode != 0) {
            [self assignError:error code:(NSInteger)PFCode];
        }
    } inMode:RAR_OM_EXTRACT error:&innerError];

    if (error) {
        *error = innerError ? innerError : nil;

        if (innerError) {
            NSLog(@"Error reading buffered data from file\nfilePath: %@\nerror: %@", filePath, innerError);
        }
    }

    return success && !innerError;
}

- (BOOL)isPasswordProtected
{
    @try {
        NSError *error = nil;
        if (![self _unrarOpenFile:self.filename
                           inMode:RAR_OM_EXTRACT
                     withPassword:nil
                            error:&error])
        {
            return NO;
        }

        if (error) {
            NSLog(@"Error checking for password: %@", error);
            return NO;
        }

        int RHCode = RARReadHeaderEx(_rarFile, header);
        int PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL);

        if ([self headerContainsErrors:&error]) {
            if (error.code == ERAR_MISSING_PASSWORD) {
                return YES;
            }

            NSLog(@"Errors in header while checking for password: %@", error);
        }

        if (RHCode == ERAR_MISSING_PASSWORD || PFCode == ERAR_MISSING_PASSWORD)
            return YES;
    }
    @finally {
        [self closeFile];
    }

    return NO;
}

- (BOOL)validatePassword
{
    __block NSError *error = nil;
    __block BOOL result = NO;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        if (error) {
            NSLog(@"Error validating password: %@", error);
            return;
        }

        int RHCode = RARReadHeaderEx(_rarFile, header);
        int PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

        if ([self headerContainsErrors:&error] && error.code == ERAR_MISSING_PASSWORD) {
            NSLog(@"Errors in header while validating password: %@", error);
            return;
        }

        if (RHCode == ERAR_MISSING_PASSWORD
            || PFCode == ERAR_MISSING_PASSWORD
            || RHCode == ERAR_BAD_DATA
            || PFCode == ERAR_BAD_DATA
            || RHCode == ERAR_BAD_PASSWORD
            || PFCode == ERAR_BAD_PASSWORD)
            return;

        result = YES;
    } inMode:RAR_OM_EXTRACT error:&error];

    return success && result;
}



#pragma mark - Callback Functions


int CALLBACK CallbackProc(UINT msg, long UserData, long P1, long P2) {
    UInt8 **buffer;

    switch(msg) {
        case UCM_CHANGEVOLUME:
            break;

        case UCM_PROCESSDATA:
            buffer = (UInt8 **) UserData;
            memcpy(*buffer, (UInt8 *)P1, P2);
            // advance the buffer ptr, original m_buffer ptr is untouched
            *buffer += P2;
            break;

        case UCM_NEEDPASSWORD:
            break;
    }

    return 0;
}

int CALLBACK BufferedReadCallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKArchive *refToSelf = (__bridge URKArchive *)(void *)UserData;

    if (msg == UCM_PROCESSDATA) {
        NSData *dataChunk = [NSData dataWithBytesNoCopy:(UInt8 *)P1 length:P2 freeWhenDone:NO];
        refToSelf.bufferedReadBlock(dataChunk);
    }

    return 0;
}



#pragma mark - Private Methods


- (BOOL)performActionWithArchiveOpen:(void(^)(NSError **innerError))action
                              inMode:(NSInteger)mode
                               error:(NSError **)error
{
    @synchronized(self.threadLock) {
        if (error) {
            *error = nil;
        }

        if (![self _unrarOpenFile:self.filename
                           inMode:mode
                     withPassword:self.password
                            error:error]) {
            return NO;
        }

        @try {
            action(error);
        }
        @finally {
            [self closeFile];
        }

        return !error || !*error;
    }
}

- (BOOL)_unrarOpenFile:(NSString *)rarFile inMode:(NSInteger)mode withPassword:(NSString *)aPassword error:(NSError **)error
{
    if (error) {
        *error = nil;
    }

    ErrHandler.Clean();

    header = new RARHeaderDataEx;
    bzero(header, sizeof(RARHeaderDataEx));
	flags = new RAROpenArchiveDataEx;
    bzero(flags, sizeof(RAROpenArchiveDataEx));

	const char *filenameData = (const char *) [rarFile UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->OpenMode = (uint)mode;

	_rarFile = RAROpenArchiveEx(flags);
	if (_rarFile == 0 || flags->OpenResult != 0) {
        [self assignError:error code:(NSInteger)flags->OpenResult];
		return NO;
    }

    if(aPassword != nil) {
        char *password = (char *) [aPassword UTF8String];
        RARSetPassword(_rarFile, password);
    }

	return YES;
}

- (BOOL)closeFile;
{
    if (_rarFile)
        RARCloseArchive(_rarFile);
    _rarFile = 0;

    if (flags)
        delete flags->ArcName;
    delete flags, flags = 0;
    delete header, header = 0;
    return YES;
}

- (NSString *)errorNameForErrorCode:(NSInteger)errorCode
{
    NSString *errorName;

    switch (errorCode) {
        case ERAR_END_ARCHIVE:
            errorName = @"ERAR_END_ARCHIVE";
            break;

        case ERAR_NO_MEMORY:
            errorName = @"ERAR_NO_MEMORY";
            break;

        case ERAR_BAD_DATA:
            errorName = @"ERAR_BAD_DATA";
            break;

        case ERAR_BAD_ARCHIVE:
            errorName = @"ERAR_BAD_ARCHIVE";
            break;

        case ERAR_UNKNOWN_FORMAT:
            errorName = @"ERAR_UNKNOWN_FORMAT";
            break;

        case ERAR_EOPEN:
            errorName = @"ERAR_EOPEN";
            break;

        case ERAR_ECREATE:
            errorName = @"ERAR_ECREATE";
            break;

        case ERAR_ECLOSE:
            errorName = @"ERAR_ECLOSE";
            break;

        case ERAR_EREAD:
            errorName = @"ERAR_EREAD";
            break;

        case ERAR_EWRITE:
            errorName = @"ERAR_EWRITE";
            break;

        case ERAR_SMALL_BUF:
            errorName = @"ERAR_SMALL_BUF";
            break;

        case ERAR_UNKNOWN:
            errorName = @"ERAR_UNKNOWN";
            break;

        case ERAR_MISSING_PASSWORD:
            errorName = @"ERAR_MISSING_PASSWORD";
            break;

        case ERAR_ARCHIVE_NOT_FOUND:
            errorName = @"ERAR_ARCHIVE_NOT_FOUND";
            break;

        default:
            errorName = [NSString stringWithFormat:@"Unknown error code: %u", flags->OpenResult];
            break;
    }

    return errorName;
}

- (BOOL)assignError:(NSError **)error code:(NSInteger)errorCode
{
    if (error) {
        NSString *errorName = [self errorNameForErrorCode:errorCode];

        *error = [NSError errorWithDomain:URKErrorDomain
                                     code:errorCode
                                 userInfo:@{NSLocalizedFailureReasonErrorKey: errorName}];
    }

    return NO;
}

- (BOOL)headerContainsErrors:(NSError **)error
{
    BOOL isPasswordProtected = header->Flags & 0x04;

    if (isPasswordProtected && !self.password) {
        [self assignError:error code:ERAR_MISSING_PASSWORD];
        return YES;
    }

    return NO;
}

@end
