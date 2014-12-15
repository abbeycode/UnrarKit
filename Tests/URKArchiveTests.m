//
//  URKArchiveTests.m
//  UnrarKit Tests
//
//

#import <XCTest/XCTest.h>
#import <UnrarKit/URKArchive.h>
#import <zlib.h>

#import "URKFileInfo.h"

@interface URKArchiveTests : XCTestCase

@property BOOL testFailed;

@property NSURL *tempDirectory;
@property NSMutableDictionary *testFileURLs;
@property NSMutableDictionary *unicodeFileURLs;
@property NSURL *corruptArchive;

@end

@implementation URKArchiveTests



#pragma mark - Test Management


- (void)setUp
{
    [super setUp];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *uniqueName = [self randomDirectoryName];
    NSError *error = nil;
    
    NSArray *testFiles = @[@"Large Archive.rar",
                           @"Test Archive.rar",
                           @"Test Archive (Password).rar",
                           @"Test Archive (Header Password).rar",
                           @"Test File A.txt",
                           @"Test File B.jpg",
                           @"Test File C.m4a"];
    
    NSArray *unicodeFiles = @[@"Ⓣest Ⓐrchive.rar",
                              @"Test File Ⓐ.txt",
                              @"Test File Ⓑ.jpg",
                              @"Test File Ⓒ.m4a"];
    
    NSString *tempDirSubtree = [@"UnrarKitTest" stringByAppendingPathComponent:uniqueName];
    
    self.testFailed = NO;
    self.testFileURLs = [[NSMutableDictionary alloc] init];
    self.unicodeFileURLs = [[NSMutableDictionary alloc] init];
    self.tempDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempDirSubtree]
                                    isDirectory:YES];

    NSLog(@"Temp directory: %@", self.tempDirectory);
    
    [fm createDirectoryAtURL:self.tempDirectory
 withIntermediateDirectories:YES
                  attributes:nil
                       error:&error];
    
    XCTAssertNil(error, @"Failed to create temp directory: %@", self.tempDirectory);

    NSMutableArray *filesToCopy = [NSMutableArray arrayWithArray:testFiles];
    [filesToCopy addObjectsFromArray:unicodeFiles];
    
    for (NSString *file in filesToCopy) {
        NSURL *testFileURL = [self urlOfTestFile:file];
        BOOL testFileExists = [fm fileExistsAtPath:testFileURL.path];
        XCTAssertTrue(testFileExists, @"%@ not found", file);
        
        NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:file];
        
        NSError *error = nil;
        [fm copyItemAtURL:testFileURL
                    toURL:destinationURL
                    error:&error];
        
        XCTAssertNil(error, @"Failed to copy temp file %@ from %@ to %@",
                     file, testFileURL, destinationURL);
        
        if ([testFiles containsObject:file]) {
            [self.testFileURLs setObject:destinationURL forKey:file];
        }
        else if ([unicodeFiles containsObject:file]) {
            [self.unicodeFileURLs setObject:destinationURL forKey:file];
        }
    }
    
    // Make a "corrupt" rar file
    NSURL *m4aFileURL = [self urlOfTestFile:@"Test File C.m4a"];
    self.corruptArchive = [self.tempDirectory URLByAppendingPathComponent:@"corrupt.rar"];
    [fm copyItemAtURL:m4aFileURL
                toURL:self.corruptArchive
                error:&error];
    
    XCTAssertNil(error, @"Failed to create corrupt archive (copy from %@ to %@)", m4aFileURL, self.corruptArchive);
}

- (void)tearDown
{
    if (!self.testFailed) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:self.tempDirectory error:&error];
        
        XCTAssertNil(error, @"Error deleting temp directory");
    }
    
    [super tearDown];
}

- (void) recordFailureWithDescription:(NSString *) description inFile:(NSString *) filename atLine:(NSUInteger) lineNumber expected:(BOOL) expected;
{
    self.testFailed = YES;
    [super recordFailureWithDescription:description inFile:filename atLine:lineNumber expected:expected];
}



#pragma mark - Test Cases


- (void)testFileURL {
    NSArray *testArchives = @[@"Large Archive.rar",
                              @"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing fileURL of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
        
        NSURL *resolvedURL = archive.fileURL.URLByResolvingSymlinksInPath;
        XCTAssertNotNil(resolvedURL, @"Nil URL returned for valid archive");
        XCTAssertTrue([testArchiveURL isEqual:resolvedURL], @"Resolved URL doesn't match original");
    }
}

- (void)testFilename {
    NSArray *testArchives = @[@"Large Archive.rar",
                              @"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing filename of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
        
        NSString *resolvedFilename = archive.filename;
        XCTAssertNotNil(resolvedFilename, @"Nil filename returned for valid archive");
        
        // Testing by suffix, since the original points to /private/var, but the resolved one
        // points straight to /var. They're equivalent, but not character-for-character equal
        XCTAssertTrue([resolvedFilename hasSuffix:testArchiveURL.path],
                      @"Resolved filename doesn't match original");
    }
}
- (void)testListFilenames
{
    NSArray *testArchives = @[@"Test Archive.rar", @"Test Archive (Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];

        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
        
        NSError *error = nil;
        NSArray *filesInArchive = [archive listFilenames:&error];
        
        XCTAssertNil(error, @"Error returned by unrarListFiles");
        XCTAssertNotNil(filesInArchive, @"No list of files returned");
        XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < filesInArchive.count; i++) {
            NSString *archiveFilename = filesInArchive[i];
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);

            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testListFilenames_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error returned by unrarListFiles");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");
    
    for (NSInteger i = 0; i < filesInArchive.count; i++) {
        NSString *archiveFilename = filesInArchive[i];
        NSString *expectedFilename = expectedFiles[i];
        
        XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
    }
}

- (void)testListFilenames_HeaderPassword
{
    NSArray *testArchives = @[@"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];

        URKArchive *archiveNoPassword = [URKArchive rarArchiveAtURL:testArchiveURL];
        
        NSError *error = nil;
        NSArray *filesInArchive = [archiveNoPassword listFilenames:&error];
        
        XCTAssertNotNil(error, @"No error returned by unrarListFiles (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:@"password"];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFilenames:&error];
        
        XCTAssertNil(error, @"Error returned by unrarListFiles");
        XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < filesInArchive.count; i++) {
            NSString *archiveFilename = filesInArchive[i];
            NSString *expectedFilename = expectedFiles[i];

            NSLog(@"Testing for file %@", expectedFilename);

            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testListFilenames_NoHeaderPasswordGiven
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test Archive (Header Password).rar"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFilenames:&error];
    
    XCTAssertNotNil(error, @"List without password succeeded");
    XCTAssertNil(files, @"List returned without password");
    XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
}

- (void)testListFilenames_InvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFilenames:&error];
    
    XCTAssertNotNil(error, @"List files of invalid archive succeeded");
    XCTAssertNil(files, @"List returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testListFileInfo {
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test Archive.rar"]];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];

    static NSDateFormatter *testFileInfoDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testFileInfoDateFormatter = [[NSDateFormatter alloc] init];
        testFileInfoDateFormatter.dateFormat = @"M/dd/yyyy h:mm a";
        testFileInfoDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    });
    
    NSDictionary *expectedTimestamps = @{@"Test File A.txt": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:02 PM"],
                                         @"Test File B.jpg": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:04 PM"],
                                         @"Test File C.m4a": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:05 PM"],};
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFileInfo:&error];
        
    XCTAssertNil(error, @"Error returned by listFileInfo");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFileSet.count, @"Incorrect number of files listed in archive");
    
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSInteger i = 0; i < filesInArchive.count; i++) {
        URKFileInfo *fileInfo = filesInArchive[i];
       
        // Test Archive Name
        NSString *expectedArchiveName = archive.filename;
        XCTAssertEqualObjects(fileInfo.archiveName, expectedArchiveName, @"Incorrect archive name");
        
        // Test Filename
        NSString *expectedFilename = expectedFiles[i];
        XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Incorrect filename");
        
        // Test CRC
        NSUInteger expectedFileCRC = [self crcOfTestFile:expectedFilename];
        XCTAssertEqual(fileInfo.CRC, expectedFileCRC, @"Incorrect CRC checksum");
        
        // Test Last Modify Date
        NSTimeInterval archiveFileTimeInterval = [fileInfo.timestamp timeIntervalSinceReferenceDate];
        NSTimeInterval expectedFileTimeInterval = [expectedTimestamps[fileInfo.filename] timeIntervalSinceReferenceDate];
        XCTAssertEqualWithAccuracy(archiveFileTimeInterval, expectedFileTimeInterval, 60, @"Incorrect file timestamp (more than 60 seconds off)");

        // Test Uncompressed Size
        NSError *attributesError = nil;
        NSString *expectedFilePath = [[self urlOfTestFile:expectedFilename] path];
        NSDictionary *expectedFileAttributes = [fm attributesOfItemAtPath:expectedFilePath
                                                                    error:&attributesError];
        XCTAssertNil(attributesError, @"Error getting file attributes of %@", expectedFilename);
       
        long long expectedFileSize = expectedFileAttributes.fileSize;
        XCTAssertEqual(fileInfo.uncompressedSize, expectedFileSize, @"Incorrect uncompressed file size");
        
        // Test Compression method
        XCTAssertEqual(fileInfo.compressionMethod, URKCompressionMethodNormal, @"Incorrect compression method");
        
        // Test Host OS
        XCTAssertEqual(fileInfo.hostOS, URKHostOSUnix, @"Incorrect host OS");
    }
}

- (void)testListFileInfo_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFileInfo:&error];
    
    XCTAssertNil(error, @"Error returned by unrarListFiles");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");
    
    for (NSInteger i = 0; i < filesInArchive.count; i++) {
        URKFileInfo *fileInfo = (URKFileInfo *)filesInArchive[i];
        
        XCTAssertEqualObjects(fileInfo.filename, expectedFiles[i], @"Incorrect filename listed");
        XCTAssertEqualObjects(fileInfo.archiveName, archive.filename, @"Incorrect archiveName listed");
    }
}

- (void)testListFileInfo_HeaderPassword
{
    NSArray *testArchives = @[@"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archiveNoPassword = [URKArchive rarArchiveAtURL:testArchiveURL];
        
        NSError *error = nil;
        NSArray *filesInArchive = [archiveNoPassword listFileInfo:&error];
        
        XCTAssertNotNil(error, @"No error returned by unrarListFiles (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:@"password"];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFileInfo:&error];
        
        XCTAssertNil(error, @"Error returned by unrarListFiles");
        XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < filesInArchive.count; i++) {
            URKFileInfo *archiveFileInfo = filesInArchive[i];
            NSString *archiveFilename = archiveFileInfo.filename;
            NSString *expectedFilename = expectedFiles[i];
            
            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testListFileInfo_NoHeaderPasswordGiven {
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test Archive (Header Password).rar"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNotNil(error, @"List without password succeeded");
    XCTAssertNil(files, @"List returned without password");
    XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
}

- (void)testListFileInfo_InvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNotNil(error, @"List files of invalid archive succeeded");
    XCTAssertNil(files, @"List returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testExtractFiles
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                      [testArchiveName stringByDeletingPathExtension]];
        NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
        
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:password];
        
        NSError *error = nil;
        BOOL success = [archive extractFilesTo:extractURL.path overWrite:NO error:&error];
        
        XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
        XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
        
        error = nil;
        NSArray *extractedFiles = [fm contentsOfDirectoryAtPath:extractURL.path
                                                          error:&error];
        
        XCTAssertNil(error, @"Failed to list contents of extract directory: %@", extractURL);
        
        XCTAssertNotNil(extractedFiles, @"No list of files returned");
        XCTAssertEqual(extractedFiles.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < extractedFiles.count; i++) {
            NSString *extractedFilename = extractedFiles[i];
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);
            
            XCTAssertEqualObjects(extractedFilename, expectedFilename, @"Incorrect filename listed");
            
            NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:extractedFilename];
            NSURL *expectedFileURL = self.testFileURLs[expectedFilename];
            
            NSData *extractedFileData = [NSData dataWithContentsOfURL:extractedFileURL];
            NSData *expectedFileData = [NSData dataWithContentsOfURL:expectedFileURL];
            
            XCTAssertTrue([expectedFileData isEqualToData:extractedFileData], @"Data in file doesn't match source");
        }
    }
}

- (void)testExtractFiles_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *testArchiveName = @"Ⓣest Ⓐrchive.rar";
    NSURL *testArchiveURL = self.unicodeFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path overWrite:NO error:&error];
    
    XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    error = nil;
    NSArray *extractedFiles = [fm contentsOfDirectoryAtPath:extractURL.path
                                                      error:&error];
    
    XCTAssertNil(error, @"Failed to list contents of extract directory: %@", extractURL);
    
    XCTAssertNotNil(extractedFiles, @"No list of files returned");
    XCTAssertEqual(extractedFiles.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");
    
    for (NSInteger i = 0; i < extractedFiles.count; i++) {
        NSString *extractedFilename = extractedFiles[i];
        NSString *expectedFilename = expectedFiles[i];
        
        XCTAssertEqualObjects(extractedFilename, expectedFilename, @"Incorrect filename listed");
        
        NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:extractedFilename];
        NSURL *expectedFileURL = self.unicodeFileURLs[expectedFilename];
        
        NSData *extractedFileData = [NSData dataWithContentsOfURL:extractedFileURL];
        NSData *expectedFileData = [NSData dataWithContentsOfURL:expectedFileURL];
        
        XCTAssertTrue([expectedFileData isEqualToData:extractedFileData], @"Data in file doesn't match source");
    }
}

- (void)testExtractFiles_NoPasswordGiven
{
    NSArray *testArchives = @[@"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction archive (no password given): %@", testArchiveName);
        URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[testArchiveName]];
        
        NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                      [testArchiveName stringByDeletingPathExtension]];
        NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
        
        
        NSError *error = nil;
        BOOL success = [archive extractFilesTo:extractURL.path overWrite:NO error:&error];
        BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
        
        XCTAssertFalse(success, @"Extract without password succeeded");
        XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
        XCTAssertFalse(dirExists, @"Directory successfully created without password");
    }
}

- (void)testExtractFiles_InvalidArchive
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"ExtractInvalidArchive"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path overWrite:NO error:&error];
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    
    XCTAssertFalse(success, @"Extract invalid archive succeeded");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
    XCTAssertFalse(dirExists, @"Directory successfully created for invalid archive");
}

- (void)testExtractData
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction of data from archive %@", testArchiveName);

        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:password];
        
        for (NSInteger i = 0; i < expectedFiles.count; i++) {
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);
            
            NSError *error = nil;
            NSData *extractedData = [archive extractDataFromFile:expectedFilename error:&error];
            
            XCTAssertNil(error, @"Error in extractStream:error:");
            
            NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
            
            XCTAssertNotNil(extractedData, @"No data extracted");
            XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
        }
    }
}

- (void)testExtractData_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    for (NSInteger i = 0; i < expectedFiles.count; i++) {
        NSString *expectedFilename = expectedFiles[i];
        
        NSError *error = nil;
        NSData *extractedData = [archive extractDataFromFile:expectedFilename error:&error];
        
        XCTAssertNil(error, @"Error in extractStream:error:");
        
        NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
        
        XCTAssertNotNil(extractedData, @"No data extracted");
        XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
    }
}

- (void)testExtractData_NoPassword
{
    NSArray *testArchives = @[@"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction of data from archive (no password given): %@", testArchiveName);
        URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[testArchiveName]];
        
        NSError *error = nil;
        NSData *data = [archive extractDataFromFile:@"Test File A.txt" error:&error];
        
        XCTAssertNotNil(error, @"Extract data without password succeeded");
        XCTAssertNil(data, @"Data returned without password");
        XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
    }
}

- (void)testExtractData_InvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"Any file.txt" error:&error];
    
    XCTAssertNotNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNil(data, @"Data returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testExtractData_FileMoved
{
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"unittest"];
        
        NSError *renameError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
        XCTAssertNil(error, @"Error renaming file: %@", renameError);
    });
    
    NSMutableSet *allDirectories = [NSMutableSet set];
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        [allDirectories addObjectsFromArray:fileInfo.filename.stringByDeletingLastPathComponent.pathComponents];
        
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        // All non-directory files must be non-empty
        if (![allDirectories containsObject:fileInfo.filename]) {
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testExtractData_FileDeleted
{
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSError *removeError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtURL:largeArchiveURL error:&removeError];
        XCTAssertNil(error, @"Error removing file: %@", removeError);
    });
    
    NSMutableSet *allDirectories = [NSMutableSet set];
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        [allDirectories addObjectsFromArray:fileInfo.filename.stringByDeletingLastPathComponent.pathComponents];
        
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);

        // All non-directory files must be non-empty
        if (![allDirectories containsObject:fileInfo.filename]) {
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testExtractData_FileMovedBeforeBegin
{
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"unittest"];
    
    NSError *renameError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
    XCTAssertNil(error, @"Error renaming file: %@", renameError);
    
    NSMutableSet *allDirectories = [NSMutableSet set];
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        [allDirectories addObjectsFromArray:fileInfo.filename.stringByDeletingLastPathComponent.pathComponents];
        
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        // All non-directory files must be non-empty
        if (![allDirectories containsObject:fileInfo.filename]) {
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testFileDescriptorUsage
{
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveOriginalURL = self.testFileURLs[testArchiveName];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSInteger i = 0; i < 1000; i++) {
        NSString *tempDir = [self randomDirectoryName];
        NSURL *tempDirURL = [self.tempDirectory URLByAppendingPathComponent:tempDir];
        NSURL *testArchiveCopyURL = [tempDirURL URLByAppendingPathComponent:testArchiveName];
        
        NSError *error = nil;
        [fm createDirectoryAtURL:tempDirURL
     withIntermediateDirectories:YES
                      attributes:nil
                           error:&error];
        
        XCTAssertNil(error, @"Error creating temp directory: %@", tempDirURL);
        
        [fm copyItemAtURL:testArchiveOriginalURL toURL:testArchiveCopyURL error:&error];
        XCTAssertNil(error, @"Error copying test archive \n from: %@ \n\n   to: %@", testArchiveOriginalURL, testArchiveCopyURL);

        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveCopyURL];
        
        NSArray *fileList = [archive listFilenames:&error];
        XCTAssertNotNil(fileList);
        
        for (NSString *fileName in fileList) {
            NSData *fileData = [archive extractDataFromFile:fileName error:&error];
            XCTAssertNotNil(fileData);
            XCTAssertNil(error);
        }
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}

- (void)testErrorIsCorrect
{
    NSError *error = nil;
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.corruptArchive];
    XCTAssertNil([archive listFilenames:&error], "Listing filenames in corrupt archive should return nil");
    XCTAssertNotNil(error, @"An error should be returned when listing filenames in a corrupt archive");
    XCTAssertNotNil(error.description, @"Error's description is nil");
}

- (void)testIsPasswordProtected_PasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Password).rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertTrue(archive.isPasswordProtected, @"isPasswordProtected = NO for password-protected archive");
}

- (void)testIsPasswordProtected_HeaderPasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Header Password).rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertTrue(archive.isPasswordProtected, @"isPasswordProtected = NO for password-protected archive");
}

- (void)testIsPasswordProtected_PasswordNotRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertFalse(archive.isPasswordProtected, @"isPasswordProtected = YES for password-protected archive");
}

- (void)testValidatePassword_PasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Password).rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when no password supplied");
    
    archive.password = @"wrong";
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when wrong password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when correct password supplied");
}

- (void)testValidatePassword_HeaderPasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Header Password).rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when no password supplied");
    
    archive.password = @"wrong";
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when wrong password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when correct password supplied");
}

- (void)testValidatePassword_PasswordNotRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when no password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when password supplied");
}

- (void)testUnicodeArchiveName
{
    NSURL *originalArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    NSString *newArchiveName = @" ♔ ♕ ♖ ♗ ♘ ♙ ♚ ♛ ♜ ♝ ♞ ♟.rar";
    
    NSURL *newArchiveURL = [[originalArchiveURL URLByDeletingLastPathComponent]
                            URLByAppendingPathComponent:newArchiveName];
    
    NSError *error = nil;
    BOOL moveSuccess = [[NSFileManager defaultManager] moveItemAtURL:originalArchiveURL
                                                               toURL:newArchiveURL
                                                               error:&error];
    XCTAssertTrue(moveSuccess, @"Failed to rename Test Archive to unicode name");
    XCTAssertNil(error, @"Error renaming Test Archive to unicode name: %@", error);
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [@"Unicode contents" stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];

    NSError *extractFilesError = nil;
    URKArchive *unicodeNamedArchive = [URKArchive rarArchiveAtURL:newArchiveURL];
    BOOL extractSuccess = [unicodeNamedArchive extractFilesTo:extractURL.path
                                                    overWrite:YES
                                                        error:&extractFilesError];
    
    XCTAssertTrue(extractSuccess, @"Failed to extract archive");
    XCTAssertNil(extractFilesError, @"Error extracting archive: %@", extractFilesError);
}



#pragma mark - Helper Methods


- (NSURL *)urlOfTestFile:(NSString *)fileName
{
    NSString *name = [fileName stringByDeletingPathExtension];
    NSString *extension = [fileName pathExtension];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:name
                                                                      ofType:extension
                                                                 inDirectory:@"Test Data"];
    return [NSURL fileURLWithPath:path];
}

- (NSString *)randomDirectoryName
{
    NSString *globallyUnique = [[NSProcessInfo processInfo] globallyUniqueString];
    NSRange firstHyphen = [globallyUnique rangeOfString:@"-"];
    return [globallyUnique substringToIndex:firstHyphen.location];
}

- (NSString *)randomDirectoryWithPrefix:(NSString *)prefix
{
    return [NSString stringWithFormat:@"%@ %@", prefix, [self randomDirectoryName]];
}

- (NSInteger)numberOfOpenFileHandles {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/lsof";
    task.arguments = @[@"-P", @"-n", @"-p", [NSString stringWithFormat:@"%d", pid]];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *lsofOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
//    NSLog(@"LSOF:\n%@", lsofOutput);
    
    return [lsofOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]].count;
}

- (NSUInteger)crcOfTestFile:(NSString *)filename {
    NSURL *fileURL = [self urlOfTestFile:filename];
    NSData *fileContents = [[NSFileManager defaultManager] contentsAtPath:[fileURL path]];
    return crc32(0, fileContents.bytes, fileContents.length);
}

@end
