//
//  URKArchive.mm
//  UnrarKit
//
//

#import "URKArchive.h"
#import "URKFileInfo.h"
#import "UnrarKitMacros.h"
#import "NSString+UnrarKit.h"

#import "rar.hpp"


NSString *URKErrorDomain = @"URKErrorDomain";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#if UNIFIED_LOGGING_SUPPORTED
os_log_t unrarkit_log;
#endif
#pragma clang diagnostic pop

static NSBundle *_resources = nil;


@interface URKArchive ()

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError **)error
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_0 || MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
NS_DESIGNATED_INITIALIZER
#endif
;

@property (strong) NSData *fileBookmark;
@property (strong) BOOL(^bufferedReadBlock)(NSData *dataChunk);

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


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *resourcesURL = [mainBundle URLForResource:@"UnrarKitResources" withExtension:@"bundle"];
        
        _resources = (resourcesURL
                      ? [NSBundle bundleWithURL:resourcesURL]
                      : mainBundle);
        
        URKLogInit();
    });
}

- (instancetype)init {
    URKLogError("Attempted to use -init method, which is no longer supported");
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
    URKCreateActivity("Init Archive");

    URKLogInfo("Initializing archive with URL %{public}@, path %{public}@, password %{public}@", fileURL, fileURL.path, [password length] != 0 ? @"given" : @"not given");
    
    if (!fileURL) {
        URKLogError("Cannot initialize archive with nil URL");
        return nil;
    }

    if ((self = [super init])) {
        if (error) {
            *error = nil;
        }

        URKLogDebug("Initializing private fields");

        NSError *bookmarkError = nil;
        _fileBookmark = [fileURL bookmarkDataWithOptions:0
                          includingResourceValuesForKeys:@[]
                                           relativeToURL:nil
                                                   error:&bookmarkError];
        _password = password;
        _threadLock = [[NSObject alloc] init];

        if (bookmarkError) {
            URKLog("Error creating bookmark to RAR archive: %@", bookmarkError);

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
    URKCreateActivity("Read Archive URL");

    BOOL bookmarkIsStale = NO;
    NSError *error = nil;

    NSURL *result = [NSURL URLByResolvingBookmarkData:self.fileBookmark
                                              options:0
                                        relativeToURL:nil
                                  bookmarkDataIsStale:&bookmarkIsStale
                                                error:&error];

    if (error) {
        URKLogFault("Error resolving bookmark to RAR archive: %{public}@", error);
        return nil;
    }

    if (bookmarkIsStale) {
        URKLogDebug("Refreshing stale bookmark");
        self.fileBookmark = [result bookmarkDataWithOptions:0
                             includingResourceValuesForKeys:@[]
                                              relativeToURL:nil
                                                      error:&error];

        if (error) {
            URKLogFault("Error creating fresh bookmark to RAR archive: %{public}@", error);
        }
  }

    return result;
}

- (NSString *)filename
{
    URKCreateActivity("Read Archive Filename");
    
    NSURL *url = self.fileURL;

    if (!url) {
        return nil;
    }

    return url.path;
}

- (NSNumber *)uncompressedSize
{
    URKCreateActivity("Read Archive Uncompressed Size");

    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo) {
        URKLogError("Error getting uncompressed size: %{public}@", listError);
        return nil;
    }
    
    if (fileInfo.count == 0) {
        URKLogInfo("No files in archive. Size == 0");
        return 0;
    }
        
    return [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
}

- (NSNumber *)compressedSize
{
    URKCreateActivity("Read Archive Compressed Size");

    NSString *filePath = self.filename;
    
    if (!filePath) {
        URKLogError("Can't get compressed size, since a file path can't be resolved");
        return nil;
    }
    
    URKLogInfo("Reading archive file attributes...");
    NSError *attributesError = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath
                                                                                error:&attributesError];
    
    if (!attributes) {
        URKLogError("Error getting compressed size of %{public}@: %{public}@", filePath, attributesError);
        return nil;
    }
    
    return [NSNumber numberWithUnsignedLongLong:attributes.fileSize];
}

- (BOOL)hasMultipleVolumes
{
    return NO;
}



#pragma mark - Zip file detection


+ (BOOL)pathIsARAR:(NSString *)filePath
{
    URKCreateActivity("Determining File Type (Path)");

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];

    if (!handle) {
        URKLogError("No file handle returned for path: %{public}@", filePath);
        return NO;
    }

    @try {
        NSData *fileData = [handle readDataOfLength:8];

        if (fileData.length < 8) {
            URKLogDebug("No file handle returned for path: %{public}@", filePath);
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
            URKLogDebug("File is not a RAR. Magic numbers != 'Rar!..'");
            return NO;
        }

        // Check for v1.5 and on
        if (dataBytes[6] == 0x00) {
            URKLogDebug("File is a RAR >= v1.5");
            return YES;
        }

        // Check for v5.0
        if (dataBytes[6] == 0x01 &&
            dataBytes[7] == 0x00) {
            URKLogDebug("File is a RAR >= v5.0");
            return YES;
        }

        URKLogDebug("File is not a ZIP. Unknown contents in 7th and 8th bytes (%02X %02X)", dataBytes[6], dataBytes[7]);
    }
    @finally {
        [handle closeFile];
    }

    return NO;
}

+ (BOOL)urlIsARAR:(NSURL *)fileURL
{
    URKCreateActivity("Determining File Type (URL)");

    if (!fileURL || !fileURL.path) {
        URKLogDebug("File is not a RAR: nil URL or path");
        return NO;
    }

    return [URKArchive pathIsARAR:fileURL.path];
}



#pragma mark - Public Methods

-(BOOL)isVolume
{
    return [self isVolume:self.fileURL];
}

- (BOOL)isVolume:(NSURL *)fileURL
{
    @try {
        NSError *error = nil;
        if (![self _unrarOpenFile:fileURL.path
                           inMode:RAR_OM_EXTRACT
                     withPassword:nil
                            error:&error])
        {
            return NO;
        }
        
        if (error) {
            NSLog(@"Error checking for volume properties: %@", error);
            return NO;
        }
        
        RARReadHeaderEx(_rarFile, header);
        bool isVolume = (header->Flags & MHD_VOLUME) != 0;
        
        return isVolume;
    }
    @finally {
        [self closeFile];
    }
    
    return NO;
}

- (NSString *)firstVolumePath
{
    return [self firstVolumePath:self.filename];
}

- (NSString *)firstVolumePath:(NSString *)filePath
{
    __block NSString *volumePath = filePath;
    
    if (filePath.length)
    {
        // Current volume scheme
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.part[0-9]+)(.*\\.rar$)" options:NSRegularExpressionCaseInsensitive error:nil];
        [regex enumerateMatchesInString:filePath options:0 range:NSMakeRange(0, [filePath length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
         {
             volumePath = [regex stringByReplacingMatchesInString:filePath options:0 range:NSMakeRange(0, filePath.length) withTemplate:@".part1$2"];
         }];
        
        if (volumePath != filePath)
            return volumePath;
        
        // Old volume scheme
        regex = [NSRegularExpression regularExpressionWithPattern:@".r[0-9]+$" options:NSRegularExpressionCaseInsensitive error:nil];
        [regex enumerateMatchesInString:filePath options:0 range:NSMakeRange(0, [filePath length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
         {
             NSString *volumeExtension = @"ar";
             volumePath = [filePath stringByDeletingPathExtension];
             volumePath = [volumePath stringByAppendingString:[NSString stringWithFormat:@".r%@", volumeExtension]];
         }];

    }

    return volumePath;
}

- (nullable NSArray<NSString*> *)listVolumePaths:(NSError **)error
{
    __block NSMutableArray<NSString*> *volumePaths = [NSMutableArray new];
    
    NSArray<URKFileInfo*> *listFileInfo = [self listFileInfo:error];
    
    if (listFileInfo == nil)
        return nil;
    
    for (URKFileInfo* info in listFileInfo) {
        if (![volumePaths containsObject:info.archiveName])
            [volumePaths addObject:info.archiveName];
    }
    
    return [NSArray arrayWithArray:volumePaths];
}

- (NSArray<NSString*> *)listFilenames:(NSError **)error
{
    URKCreateActivity("Listing Filenames");

    NSArray *files = [self listFileInfo:error];
    return [files valueForKey:@"filename"];
}

- (NSArray<URKFileInfo*> *)listFileInfo:(NSError **)error
{
    URKCreateActivity("Listing File Info");

    __block NSMutableArray *fileInfos = [NSMutableArray array];

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing List Action");

        int RHCode = 0, PFCode = 0;

        URKLogInfo("Reading through RAR header looking for files...");
        
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
            URKLogDebug("Adding object");
            [fileInfos addObject:[URKFileInfo fileInfo:header]];

            URKLogDebug("Skipping to next file...");
            if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                NSString *errorName = nil;
                [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                URKLogError("Error skipping to next header file: %@ (%d)", errorName, PFCode);
                fileInfos = nil;
                return;
            }
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            NSString *errorName = nil;
            [self assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading RAR header: %@ (%d)", errorName, RHCode);
            fileInfos = nil;
        }
    } inMode:RAR_OM_LIST_INCSPLIT error:error];

	if (!success || !fileInfos) {
        return nil;
    }

    URKLogDebug("Found %lu files", fileInfos.count);
    return [NSArray arrayWithArray:fileInfos];
}

- (nullable NSString *)firstVolumePath {
    return @"";
}

- (nullable NSURL *)firstVolumeURL {
    NSString *path = [self firstVolumePath];
    
    if (![path length]) {
        return nil;
    }
    
    return [NSURL fileURLWithPath:path];
}

- (nullable NSArray<NSString*> *)listVolumePaths:(NSError **)error
{
    return @[];
}

- (nullable NSArray<NSURL*> *)listVolumeURLs:(NSError **)error
{
    NSError *listPathsError = nil;
    NSArray<NSString*> *volumePaths = [self listVolumePaths:&listPathsError];
    
    if (!volumePaths) {
        if (error) {
            *error = listPathsError;
        }
        
        return nil;
    }
    
    NSMutableArray<NSURL*> *volumeURLs = [NSMutableArray arrayWithCapacity:volumePaths.count];
    
    for (NSString *volumePath in volumePaths) {
        [volumeURLs addObject:[NSURL fileURLWithPath:volumePath]];
    }
    
    return [NSArray arrayWithArray:volumeURLs];
}

- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
                 error:(NSError **)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractFilesTo:filePath
                      overwrite:overwrite
                       progress:nil
                          error:error];
#pragma clang diagnostic pop
}

- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
              progress:(void (^)(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed))progressBlock
                 error:(NSError **)error
{
    URKCreateActivity("Extracting Files to Directory");

    __block BOOL result = YES;

    NSError *listError = nil;
    NSArray *fileInfos = [self listFileInfo:&listError];

    if (!fileInfos || listError) {
        URKLogError("Error listing contents of archive: %{public}@", listError);

        if (error) {
            *error = listError;
        }

        return NO;
    }

    NSNumber *totalSize = [fileInfos valueForKeyPath:@"@sum.uncompressedSize"];
    __block long long bytesDecompressed = 0;

    NSProgress *progress = [self beginProgressOperation:totalSize.longLongValue];
    progress.kind = NSProgressKindFile;
	
    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing File Extraction");

        int RHCode = 0, PFCode = 0, filesExtracted = 0;
        URKFileInfo *fileInfo;

        URKLogInfo("Reading through RAR header looking for files...");
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            fileInfo = [URKFileInfo fileInfo:header];
            URKLogDebug("Extracting %{public}@", fileInfo.filename);
            NSURL *extractedURL = [[NSURL fileURLWithPath:filePath] URLByAppendingPathComponent:fileInfo.filename];
            [progress setUserInfoObject:extractedURL
                                 forKey:NSProgressFileURLKey];
            [progress setUserInfoObject:fileInfo
                                 forKey:URKProgressInfoKeyFileInfoExtracting];
            
            if ([self headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                result = NO;
                return;
            }
            
            if (progress.isCancelled) {
                NSString *errorName = nil;
                [self assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
                URKLogInfo("Halted file extraction due to user cancellation: %@", errorName);
                result = NO;
                return;
            }

            if ((PFCode = RARProcessFile(_rarFile, RAR_EXTRACT, (char *) filePath.UTF8String, NULL)) != 0) {
                NSString *errorName = nil;
                [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                URKLogError("Error extracting file: %@ (%d)", errorName, PFCode);
                result = NO;
                return;
            }
            
            [progress setUserInfoObject:@(++filesExtracted)
                                 forKey:NSProgressFileCompletedCountKey];
            [progress setUserInfoObject:@(fileInfos.count)
                                 forKey:NSProgressFileTotalCountKey];
            progress.completedUnitCount += fileInfo.uncompressedSize;
            
            if (progressBlock) {
                progressBlock(fileInfo, bytesDecompressed / totalSize.floatValue);
            }

            bytesDecompressed += fileInfo.uncompressedSize;
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            NSString *errorName = nil;
            [self assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %@ (%d)", errorName, RHCode);
            result = NO;
        }

        if (progressBlock) {
            progressBlock(fileInfo, 1.0);
        }

    } inMode:RAR_OM_EXTRACT error:error];

    return success && result;
}

- (NSData *)extractData:(URKFileInfo *)fileInfo
                  error:(NSError **)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractDataFromFile:fileInfo.filename progress:nil error:error];
#pragma clang diagnostic pop
}

- (NSData *)extractData:(URKFileInfo *)fileInfo
               progress:(void (^)(CGFloat percentDecompressed))progressBlock
                  error:(NSError **)error
{
    return [self extractDataFromFile:fileInfo.filename progress:progressBlock error:error];
}

- (NSData *)extractDataFromFile:(NSString *)filePath
                          error:(NSError **)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractDataFromFile:filePath progress:nil error:error];
#pragma clang diagnostic pop
}

- (NSData *)extractDataFromFile:(NSString *)filePath
                       progress:(void (^)(CGFloat percentDecompressed))progressBlock
                          error:(NSError **)error
{
    URKCreateActivity("Extracting Data from File");
    
    NSProgress *progress = [self beginProgressOperation:0];

    __block NSData *result = nil;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing Extraction");

        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        URKLogInfo("Reading through RAR header looking for files...");
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            if ([self headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                return;
            }

            fileInfo = [URKFileInfo fileInfo:header];

            if ([fileInfo.filename isEqualToString:filePath]) {
                URKLogDebug("Extracting %{public}@", fileInfo.filename);
                break;
            }
            else {
                URKLogDebug("Skipping %{public}@", fileInfo.filename);
                if ((PFCode = RARProcessFileW(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                    NSString *errorName = nil;
                    [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                    URKLogError("Error skipping file: %@ (%d)", errorName, PFCode);
                    return;
                }
            }
        }

        if (RHCode != ERAR_SUCCESS) {
            NSString *errorName = nil;
            [self assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %@ (%d)", errorName, RHCode);
            return;
        }

        // Empty file, or a directory
        if (fileInfo.uncompressedSize == 0) {
            URKLogDebug("%{public}@ is empty or a directory", fileInfo.filename);
            result = [NSData data];
            return;
        }

        NSMutableData *fileData = [NSMutableData dataWithCapacity:(NSUInteger)fileInfo.uncompressedSize];
        CGFloat totalBytes = fileInfo.uncompressedSize;
        progress.totalUnitCount = totalBytes;
        __block long long bytesRead = 0;

        if (progressBlock) {
            progressBlock(0.0);
        }

        RARSetCallback(_rarFile, BufferedReadCallbackProc, (long)(__bridge void *) self);
        self.bufferedReadBlock = ^BOOL(NSData *dataChunk) {
            URKLogDebug("Appending buffered data (%lu bytes)", dataChunk.length);
            [fileData appendData:dataChunk];
            progress.completedUnitCount += dataChunk.length;

            bytesRead += dataChunk.length;

            if (progressBlock) {
                progressBlock(bytesRead / totalBytes);
            }
            
            if (progress.isCancelled) {
                URKLogInfo("Cancellation initiated");
                return NO;
            }
            
            return YES;
        };
        
        URKLogInfo("Processing file...");
        PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);
        
        if (progress.isCancelled) {
            NSString *errorName = nil;
            [self assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogInfo("Returning nil data from extraction due to user cancellation: %@", errorName);
            return;
        }

        if (PFCode != 0) {
            NSString *errorName = nil;
            [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
            URKLogError("Error extracting file data: %@ (%d)", errorName, PFCode);
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
    URKCreateActivity("Performing Action on Each File");

    URKLogInfo("Listing file info");
    
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];

    if (listError || !fileInfo) {
        URKLogError("Failed to list the files in the archive: %{public}@", listError);

        if (error) {
            *error = listError;
        }

        return NO;
    }
    
    
    NSProgress *progress = [self beginProgressOperation:fileInfo.count];

    URKLogInfo("Sorting file info by name/path");
    
    NSArray *sortedFileInfo = [fileInfo sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES]]];

    {
        URKCreateActivity("Iterating Each File Info");
        
        [sortedFileInfo enumerateObjectsUsingBlock:^(URKFileInfo *info, NSUInteger idx, BOOL *stop) {
            URKLogDebug("Performing action on %{public}@", info.filename);
            action(info, stop);
            progress.completedUnitCount += 1;
            
            if (*stop) {
                URKLogInfo("Action dictated an early stop");
                progress.completedUnitCount = progress.totalUnitCount;
            }
            
            if (progress.isCancelled) {
                URKLogInfo("File info iteration was cancelled");
                *stop = YES;
            }
        }];
    }

    return YES;
}

- (BOOL)performOnDataInArchive:(void (^)(URKFileInfo *, NSData *, BOOL *))action
                         error:(NSError **)error
{
    URKCreateActivity("Performing Action on Each File's Data");

    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo || listError) {
        URKLogError("Error listing contents of archive: %{public}@", listError);
        
        if (error) {
            *error = listError;
        }
        
        return NO;
    }
    
    NSNumber *totalSize = [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;

        BOOL stop = NO;

        NSProgress *progress = [self beginProgressOperation:totalSize.longLongValue];
        
        URKLogInfo("Reading through RAR header looking for files...");
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
            if (stop || progress.isCancelled) {
                URKLogDebug("Action dictated an early stop");
                return;
            }
            
            if ([self headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                return;
            }
            
            URKFileInfo *info = [URKFileInfo fileInfo:header];
            URKLogDebug("Performing action on %{public}@", info.filename);

            // Empty file, or a directory
            if (info.uncompressedSize == 0) {
                URKLogDebug("%{public}@ is an empty file, or a directory", info.filename);
                action(info, [NSData data], &stop);
                continue;
            }

            UInt8 *buffer = (UInt8 *)malloc((size_t)info.uncompressedSize * sizeof(UInt8));
            UInt8 *callBackBuffer = buffer;

            RARSetCallback(_rarFile, CallbackProc, (long) &callBackBuffer);

            URKLogInfo("Processing file...");
            PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

            if (PFCode != 0) {
                NSString *errorName = nil;
                [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                URKLogError("Error processing file: %@ (%d)", errorName, PFCode);
                return;
            }

            URKLogDebug("Performing action on data (%lld bytes)", info.uncompressedSize);
            NSData *data = [NSData dataWithBytesNoCopy:buffer length:(NSUInteger)info.uncompressedSize freeWhenDone:YES];
            action(info, data, &stop);
            
            progress.completedUnitCount += data.length;
        }
        
        if (progress.isCancelled) {
            NSString *errorName = nil;
            [self assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogInfo("Returning NO from performOnData:error: due to user cancellation: %@", errorName);
            return;
        }

        if (RHCode != ERAR_SUCCESS && RHCode != ERAR_END_ARCHIVE) {
            NSString *errorName = nil;
            [self assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %@ (%d)", errorName, RHCode);
            return;
        }
    } inMode:RAR_OM_EXTRACT error:error];

    return success;
}

- (BOOL)extractBufferedDataFromFile:(NSString *)filePath
                              error:(NSError **)error
                             action:(void(^)(NSData *dataChunk, CGFloat percentDecompressed))action
{
    URKCreateActivity("Extracting Buffered Data");

    NSError *innerError = nil;

    NSProgress *progress = [self beginProgressOperation:0];

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing action");

        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        URKLogInfo("Looping through files, looking for %@...", filePath);
        
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == ERAR_SUCCESS) {
            if ([self headerContainsErrors:innerError]) {
                URKLogDebug("Header contains error")
                return;
            }

            URKLogDebug("Getting file info from header");
            fileInfo = [URKFileInfo fileInfo:header];

            if ([fileInfo.filename isEqualToString:filePath]) {
                URKLogDebug("Found desired file");
                break;
            }
            else {
                URKLogDebug("Skipping file...");
                if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                    NSString *errorName = nil;
                    [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                    URKLogError("Failed to skip file: %@ (%d)", errorName, PFCode);
                    return;
                }
            }
        }
        
        CGFloat totalBytes = fileInfo.uncompressedSize;
        progress.totalUnitCount = totalBytes;
        
        if (RHCode != ERAR_SUCCESS) {
            NSString *errorName = nil;
            [self assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Header read yielded error: %@ (%d)", errorName, RHCode);
            return;
        }

        // Empty file, or a directory
        if (totalBytes == 0) {
            URKLogInfo("File is empty or a directory");
            return;
        }

        __block long long bytesRead = 0;

        // Repeating the argument instead of using positional specifiers, because they don't work with the {} formatters
        URKLogDebug("Uncompressed size: %{iec-bytes}lld (%lld bytes) in file", (long long)totalBytes, (long long)totalBytes);

        RARSetCallback(_rarFile, BufferedReadCallbackProc, (long)(__bridge void *) self);
        self.bufferedReadBlock = ^BOOL(NSData *dataChunk) {
            if (progress.isCancelled) {
                URKLogInfo("Buffered data read cancelled");
                return NO;
            }
            
            bytesRead += dataChunk.length;
            progress.completedUnitCount += dataChunk.length;

            CGFloat progressPercent = bytesRead / totalBytes;
            URKLogDebug("Read data chunk of size %lu (%.3f%% complete). Calling handler...", dataChunk.length, progressPercent * 100);
            action(dataChunk, progressPercent);
            return YES;
        };

        URKLogDebug("Processing file...");
        PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

        if (progress.isCancelled) {
            NSString *errorName = nil;
            [self assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogError("Buffered data extraction has been cancelled: %@", errorName);
            return;
        }
        
        if (PFCode != 0) {
            NSString *errorName = nil;
            [self assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
            URKLogError("Error processing file: %@ (%d)", errorName, PFCode);
        }
    } inMode:RAR_OM_EXTRACT error:&innerError];

    if (error) {
        *error = innerError ? innerError : nil;

        if (innerError) {
            URKLogError("Error reading buffered data from file\nfilePath: %{public}@\nerror: %{public}@", filePath, innerError);
        }
    }

    return success && !innerError;
}

- (BOOL)isPasswordProtected
{
    URKCreateActivity("Checking Password Protection");

    @try {
        URKLogDebug("Opening archive");
        
        NSError *error = nil;
        if (![self _unrarOpenFile:self.filename
                           inMode:RAR_OM_EXTRACT
                     withPassword:nil
                            error:&error])
        {
            URKLogError("Failed to open archive while checking for password: %{public}@", error);
            return NO;
        }

        URKLogDebug("Reading header and starting processing...");
        
        int RHCode = RARReadHeaderEx(_rarFile, header);
        int PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL);

        URKLogDebug("Checking header");
        if ([self headerContainsErrors:&error]) {
            if (error.code == ERAR_MISSING_PASSWORD) {
                URKLogDebug("Password is missing");
                return YES;
            }

            URKLogError("Errors in header while checking for password: %{public}@", error);
        }

        if (RHCode == ERAR_MISSING_PASSWORD || PFCode == ERAR_MISSING_PASSWORD) {
            URKLogDebug("Missing password indicated by RHCode (%d) or PFCode (%d)", RHCode, PFCode);
            return YES;
        }
    }
    @finally {
        [self closeFile];
    }

    URKLogDebug("Archive is not password protected");
    return NO;
}

- (BOOL)validatePassword
{
    URKCreateActivity("Validating Password");

    __block NSError *error = nil;
    __block BOOL passwordIsGood = YES;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing action");

        URKLogDebug("Opening and processing archive...");
        
        int RHCode = RARReadHeaderEx(_rarFile, header);
        int PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

        if ([self headerContainsErrors:innerError]) {
            if (error.code == ERAR_MISSING_PASSWORD) {
                URKLogDebug("Password invalidated by header");
                passwordIsGood = NO;
            }
            else {
                URKLogError("Errors in header while validating password: %{public}@", error);
            }

            return;
        }

        if (RHCode == ERAR_MISSING_PASSWORD || PFCode == ERAR_MISSING_PASSWORD
            || RHCode == ERAR_BAD_DATA || PFCode == ERAR_BAD_DATA
            || RHCode == ERAR_BAD_PASSWORD || PFCode == ERAR_BAD_PASSWORD)
        {
            URKLogDebug("Missing/bad password indicated by RHCode (%d) or PFCode (%d)", RHCode, PFCode);
            passwordIsGood = NO;
            return;
        }
    } inMode:RAR_OM_EXTRACT error:&error];

    if (!success) {
        URKLogError("Error validating password: %{public}@", error);
        return NO;
    }
    
    return passwordIsGood;
}



#pragma mark - Callback Functions


int CALLBACK CallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKCreateActivity("CallbackProc");

    UInt8 **buffer;

    switch(msg) {
        case UCM_CHANGEVOLUME:
            URKLogDebug("msg: UCM_CHANGEVOLUME");
            break;

        case UCM_PROCESSDATA:
            URKLogDebug("msg: UCM_PROCESSDATA; Copying data");
            buffer = (UInt8 **) UserData;
            memcpy(*buffer, (UInt8 *)P1, P2);
            // advance the buffer ptr, original m_buffer ptr is untouched
            *buffer += P2;
            break;

        case UCM_NEEDPASSWORD:
            URKLogDebug("msg: UCM_NEEDPASSWORD");
            break;
    }

    return 0;
}

int CALLBACK BufferedReadCallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKCreateActivity("BufferedReadCallbackProc");
    URKArchive *refToSelf = (__bridge URKArchive *)(void *)UserData;

    if (msg == UCM_PROCESSDATA) {
        URKLogDebug("msg: UCM_PROCESSDATA; Copying data chunk and calling read block");
        NSData *dataChunk = [NSData dataWithBytesNoCopy:(UInt8 *)P1 length:P2 freeWhenDone:NO];
        BOOL cancelRequested = !refToSelf.bufferedReadBlock(dataChunk);
        if (cancelRequested) {
            return -1;
        }
    }

    return 0;
}



#pragma mark - Private Methods


- (BOOL)performActionWithArchiveOpen:(void(^)(NSError **innerError))action
                              inMode:(NSInteger)mode
                               error:(NSError **)error
{
    URKCreateActivity("-performActionWithArchiveOpen:inMode:error:");

    @synchronized(self.threadLock) {
        URKLogDebug("Entered lock");
        
        if (error) {
            URKLogDebug("Error pointer passed in");
            *error = nil;
        }

        URKLogDebug("Opening archive");
        NSError *openFileError = nil;
        
        if (![self _unrarOpenFile:self.filename
                           inMode:mode
                     withPassword:self.password
                            error:&openFileError]) {
            URKLogError("Failed to open archive: %@", openFileError);
            
            if (error) {
                *error = openFileError;
            }
            
            return NO;
        }

        NSError *actionError = nil;
        
        @try {
            URKLogDebug("Calling action block");
            action(&actionError);
        }
        @finally {
            [self closeFile];
        }

        if (actionError) {
            URKLogError("Action block returned error: %@", actionError);
            
            if (error){
                *error = actionError;
            }
        }
        
        return !actionError;
    }
}

- (BOOL)_unrarOpenFile:(NSString *)rarFile inMode:(NSInteger)mode withPassword:(NSString *)aPassword error:(NSError **)error
{
    URKCreateActivity("-_unrarOpenFile:inMode:withPassword:error:");

    if (error) {
        URKLogDebug("Error pointer passed in");
        *error = nil;
    }

    URKLogDebug("Zeroing out fields...");
    
    ErrHandler.Clean();

    header = new RARHeaderDataEx;
    bzero(header, sizeof(RARHeaderDataEx));
	flags = new RAROpenArchiveDataEx;
    bzero(flags, sizeof(RAROpenArchiveDataEx));

    URKLogDebug("Setting archive name...");
    
	const char *filenameData = (const char *) [rarFile UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->OpenMode = (uint)mode;

    URKLogDebug("Opening archive %{public}@...", rarFile);
    
	_rarFile = RAROpenArchiveEx(flags);
	if (_rarFile == 0 || flags->OpenResult != 0) {
        NSString *errorName = nil;
        [self assignError:error code:(NSInteger)flags->OpenResult errorName:&errorName];
        URKLogError("Error opening archive: %@ (%d)", errorName, flags->OpenResult);
        return NO;
    }

    if(aPassword != nil) {
        URKLogDebug("Setting password...");
        char *password = (char *) [aPassword UTF8String];
        RARSetPassword(_rarFile, password);
    }

	return YES;
}

- (BOOL)closeFile
{
    URKCreateActivity("-closeFile");

    if (_rarFile) {
        URKLogDebug("Closing archive %{public}@...", self.filename);
        RARCloseArchive(_rarFile);
    }
    
    URKLogDebug("Cleaning up fields...");
    
    _rarFile = 0;

    if (flags)
        delete flags->ArcName;
    delete flags; flags = 0;
    delete header; header = 0;
    return YES;
}

- (NSString *)errorNameForErrorCode:(NSInteger)errorCode detail:(NSString **)errorDetail
{
    NSAssert(errorDetail != NULL, @"errorDetail out parameter not given");
    
    NSString *errorName;
    NSString *detail = @"";

    switch (errorCode) {
        case URKErrorCodeEndOfArchive:
            errorName = @"ERAR_END_ARCHIVE";
            break;

        case URKErrorCodeNoMemory:
            errorName = @"ERAR_NO_MEMORY";
            detail = NSLocalizedStringFromTableInBundle(@"Ran out of memory while reading archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeBadData:
            errorName = @"ERAR_BAD_DATA";
            detail = NSLocalizedStringFromTableInBundle(@"Archive has a corrupt header", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeBadArchive:
            errorName = @"ERAR_BAD_ARCHIVE";
            detail = NSLocalizedStringFromTableInBundle(@"File is not a valid RAR archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeUnknownFormat:
            errorName = @"ERAR_UNKNOWN_FORMAT";
            detail = NSLocalizedStringFromTableInBundle(@"RAR headers encrypted in unknown format", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeOpen:
            errorName = @"ERAR_EOPEN";
            detail = NSLocalizedStringFromTableInBundle(@"Failed to open a reference to the file", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeCreate:
            errorName = @"ERAR_ECREATE";
            detail = NSLocalizedStringFromTableInBundle(@"Failed to create the target directory for extraction", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeClose:
            errorName = @"ERAR_ECLOSE";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while closing the archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeRead:
            errorName = @"ERAR_EREAD";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while reading the archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeWrite:
            errorName = @"ERAR_EWRITE";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while writing a file to disk", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeSmall:
            errorName = @"ERAR_SMALL_BUF";
            detail = NSLocalizedStringFromTableInBundle(@"Buffer too small to contain entire comments", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeUnknown:
            errorName = @"ERAR_UNKNOWN";
            detail = NSLocalizedStringFromTableInBundle(@"An unknown error occurred", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeMissingPassword:
            errorName = @"ERAR_MISSING_PASSWORD";
            detail = NSLocalizedStringFromTableInBundle(@"No password given to unlock a protected archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeArchiveNotFound:
            errorName = @"ERAR_ARCHIVE_NOT_FOUND";
            detail = NSLocalizedStringFromTableInBundle(@"Unable to find the archive", @"UnrarKit", _resources, @"Error detail string");
            break;
            
        case URKErrorCodeUserCancelled:
            errorName = @"ERAR_USER_CANCELLED";
            detail = NSLocalizedStringFromTableInBundle(@"User cancelled the operation in progress", @"UnrarKit", _resources, @"Error detail string");
   break;

        default:
            errorName = [NSString stringWithFormat:@"Unknown (%ld)", (long)errorCode];
            detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Unknown error encountered (code %ld)", @"UnrarKit", _resources, @"Error detail string"), errorCode];
            break;
    }

    *errorDetail = detail;
    return errorName;
}

- (BOOL)assignError:(NSError **)error code:(NSInteger)errorCode errorName:(NSString **)outErrorName
{
    if (error) {
        NSAssert(outErrorName, @"An out variable for errorName must be provided");
        
        NSString *errorDetail = nil;
        *outErrorName = [self errorNameForErrorCode:errorCode detail:&errorDetail];

        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:
                                         @{NSLocalizedFailureReasonErrorKey: *outErrorName,
                                           NSLocalizedDescriptionKey: errorDetail,
                                           NSLocalizedRecoverySuggestionErrorKey: errorDetail}];
        
        if (self.fileURL) {
            userInfo[NSURLErrorKey] = self.fileURL;
        }
        
        *error = [NSError errorWithDomain:URKErrorDomain
                                     code:errorCode
                                 userInfo:userInfo];
    }

    return NO;
}

- (BOOL)headerContainsErrors:(NSError **)error
{
    URKCreateActivity("-headerContainsErrors:");

    BOOL isPasswordProtected = header->Flags & 0x04;

    if (isPasswordProtected && !self.password) {
        NSString *errorName = nil;
        [self assignError:error code:ERAR_MISSING_PASSWORD errorName:&errorName];
        URKLogError("Password protected and no password specified: %@ (%d)", errorName, ERAR_MISSING_PASSWORD);
        return YES;
    }

    return NO;
}

- (NSProgress *)beginProgressOperation:(NSUInteger)totalUnitCount
{
    NSProgress *progress;
    progress = self.progress;
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress]
                                             userInfo:nil];
    }
    
    if (totalUnitCount > 0) {
        progress.totalUnitCount = totalUnitCount;
    }
    
    progress.cancellable = YES;
    progress.pausable = NO;
    
    return progress;
}

@end
