//
//  URKArchiveTests.m
//  UnrarKit Tests
//
//

#import <XCTest/XCTest.h>
#import <DTPerformanceSession/DTSignalFlag.h>
#import <zlib.h>

#import <UnrarKit/URKArchive.h>
#import "URKFileInfo.h"



@interface URKArchiveTests : XCTestCase

@property BOOL testFailed;

@property NSURL *tempDirectory;
@property NSMutableDictionary *testFileURLs;
@property NSMutableDictionary *unicodeFileURLs;
@property NSURL *corruptArchive;

@end


static NSURL *originalLargeArchiveURL;


@implementation URKArchiveTests



#pragma mark - Test Management


- (void)setUp
{
    [super setUp];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *uniqueName = [self randomDirectoryName];
    NSError *error = nil;
    
    NSArray *testFiles = @[@"Test Archive.rar",
                           @"Test Archive (Password).rar",
                           @"Test Archive (Header Password).rar",
                           @"Folder Archive.rar",
                           @"Test File A.txt",
                           @"Test File B.jpg",
                           @"Test File C.m4a",
                           @"bin/rar"];
    
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
        
        NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:file isDirectory:NO];
        
        NSError *error = nil;
        if (file.pathComponents.count > 1) {
            [fm createDirectoryAtPath:destinationURL.URLByDeletingLastPathComponent.path
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            XCTAssertNil(error, @"Failed to create directories for file %@", file);
        }
        
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
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *largeTextFiles = [NSMutableArray array];
        for (NSInteger i = 0; i < 20; i++) {
            [largeTextFiles addObject:[self randomTextFileOfLength:3000000]];
        }
        
        NSError *largeArchiveError = nil;
        
        NSURL *largeArchiveURLRandomName = [self archiveWithFiles:largeTextFiles];
        originalLargeArchiveURL = [largeArchiveURLRandomName.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive (Original).rar"];
        [fm moveItemAtURL:largeArchiveURLRandomName toURL:originalLargeArchiveURL error:&largeArchiveError];
        
        XCTAssertNil(largeArchiveError, @"Error renaming original large archive: %@", largeArchiveError);
    });
    
    NSString *largeArchiveName = @"Large Archive.rar";
    NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:largeArchiveName isDirectory:NO];
    [fm copyItemAtURL:originalLargeArchiveURL toURL:destinationURL error:&error];
    XCTAssertNil(error, @"Failed to copy the Large Archive");
    
    self.testFileURLs[largeArchiveName] = destinationURL;
    
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
    NSString *largeArchiveDirectory = originalLargeArchiveURL.path.stringByDeletingLastPathComponent;
    BOOL tempDirContainsLargeArchive = [largeArchiveDirectory isEqualToString:self.tempDirectory.path];
    if (!self.testFailed && !tempDirContainsLargeArchive) {
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


#pragma mark Archive File


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


#pragma mark - RAR file Detection

#pragma By Path

- (void)testPathIsARAR
{
    NSURL *url = self.testFileURLs[@"Test Archive.rar"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertTrue(pathIsRAR, @"RAR file is not reported as a RAR");
}

- (void)testPathIsARAR_NotARAR
{
    NSURL *url = self.testFileURLs[@"Test File B.jpg"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"JPG file is reported as a RAR");
}

- (void)testPathIsARAR_SmallFile
{
    NSURL *url = [self randomTextFileOfLength:1];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"Small non-RAR file is reported as a RAR");
}

- (void)testPathIsARAR_MissingFile
{
    NSURL *url = [self.testFileURLs[@"Test Archive.rar"] URLByAppendingPathExtension:@"missing"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"Missing file is reported as a RAR");
}

- (void)testPathIsARAR_FileHandleLeaks
{
    NSURL *smallFileURL = [self randomTextFileOfLength:1];
    NSURL *jpgURL = self.testFileURLs[@"Test File B.jpg"];
    
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    for (NSInteger i = 0; i < 10000; i++) {
        BOOL smallFileIsZip = [URKArchive pathIsARAR:smallFileURL.path];
        XCTAssertFalse(smallFileIsZip, @"Small non-RAR file is reported as a RAR");
        
        BOOL jpgIsZip = [URKArchive pathIsARAR:jpgURL.path];
        XCTAssertFalse(jpgIsZip, @"JPG file is reported as a RAR");
        
        NSURL *zipURL = self.testFileURLs[@"Test Archive.rar"];
        BOOL zipFileIsZip = [URKArchive pathIsARAR:zipURL.path];
        XCTAssertTrue(zipFileIsZip, @"RAR file is not reported as a RAR");
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}

#pragma By URL

- (void)testurlIsARAR
{
    NSURL *url = self.testFileURLs[@"Test Archive.rar"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertTrue(urlIsRAR, @"RAR file is not reported as a RAR");
}

- (void)testurlIsARAR_NotARAR
{
    NSURL *url = self.testFileURLs[@"Test File B.jpg"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"JPG file is reported as a RAR");
}

- (void)testurlIsARAR_SmallFile
{
    NSURL *url = [self randomTextFileOfLength:1];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"Small non-RAR file is reported as a RAR");
}

- (void)testurlIsARAR_MissingFile
{
    NSURL *url = [self.testFileURLs[@"Test Archive.rar"] URLByAppendingPathExtension:@"missing"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"Missing file is reported as a RAR");
}

- (void)testurlIsARAR_FileHandleLeaks
{
    NSURL *smallFileURL = [self randomTextFileOfLength:1];
    NSURL *jpgURL = self.testFileURLs[@"Test File B.jpg"];
    
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    for (NSInteger i = 0; i < 10000; i++) {
        BOOL smallFileIsZip = [URKArchive urlIsARAR:smallFileURL];
        XCTAssertFalse(smallFileIsZip, @"Small non-RAR file is reported as a RAR");
        
        BOOL jpgIsZip = [URKArchive urlIsARAR:jpgURL];
        XCTAssertFalse(jpgIsZip, @"JPG file is reported as a RAR");
        
        NSURL *zipURL = self.testFileURLs[@"Test Archive.rar"];
        BOOL zipFileIsZip = [URKArchive urlIsARAR:zipURL];
        XCTAssertTrue(zipFileIsZip, @"RAR file is not reported as a RAR");
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}


#pragma mark List Filenames


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
        
        XCTAssertNil(error, @"Error returned by listFilenames");
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
    
    XCTAssertNil(error, @"Error returned by listFilenames");
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
        
        XCTAssertNotNil(error, @"No error returned by listFilenames (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:@"password"];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFilenames:&error];
        
        XCTAssertNil(error, @"Error returned by listFilenames");
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

- (void)testListFilenames_NoFilePasswordGiven
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test Archive (Password).rar"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"List without password succeeded");
    XCTAssertNotNil(files, @"List returned without password");
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


#pragma mark List File Info


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
    
    XCTAssertNil(error, @"Error returned by listFileInfo");
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
        
        XCTAssertNotNil(error, @"No error returned by listFileInfo (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:@"password"];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFileInfo:&error];
        
        XCTAssertNil(error, @"Error returned by listFileInfo");
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


#pragma mark Extract Files


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
        BOOL success = [archive extractFilesTo:extractURL.path
                                     overwrite:NO
                                      progress:^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
#if DEBUG
                                          NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
#endif
                                      }
                                         error:&error];
        
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
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
#if DEBUG
                                      NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
#endif
                                  }
                                     error:&error];
    
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
        BOOL success = [archive extractFilesTo:extractURL.path
                                     overwrite:NO
                                      progress:^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
#if DEBUG
                                          NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
#endif
                                      }
                                         error:&error];
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
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
#if DEBUG
                                      NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
#endif
                                  }
                                     error:&error];
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    
    XCTAssertFalse(success, @"Extract invalid archive succeeded");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
    XCTAssertFalse(dirExists, @"Directory successfully created for invalid archive");
}


#pragma mark Extract Data


- (void)testExtractData
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {

        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:password];
        
        NSError *error = nil;
        NSArray *fileInfos = [archive listFileInfo:&error];
        XCTAssertNil(error, @"Error reading file info");

        for (NSInteger i = 0; i < expectedFiles.count; i++) {
            NSString *expectedFilename = expectedFiles[i];
            
            NSError *error = nil;
            NSData *extractedData = [archive extractDataFromFile:expectedFilename
                                                        progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                                            NSLog(@"Extracting, %f%% complete", percentDecompressed);
#endif
                                                        }
                                                           error:&error];
            
            XCTAssertNil(error, @"Error in extractData:error:");
            
            NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
            
            XCTAssertNotNil(extractedData, @"No data extracted");
            XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
            
            error = nil;
            NSData *dataFromFileInfo = [archive extractData:fileInfos[i]
                                                   progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                                       NSLog(@"Extracting from file info, %f%% complete", percentDecompressed);
#endif
                                                   }
                                                      error:&error];
            XCTAssertNil(error, @"Error extracting data by file info");
            XCTAssertTrue([expectedFileData isEqualToData:dataFromFileInfo], @"Extracted data from file info doesn't match original file");
        }
    }
}

- (void)testExtractData_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSError *error = nil;
    NSArray *fileInfos = [archive listFileInfo:&error];
    XCTAssertNil(error, @"Error reading file info");
    
    for (NSInteger i = 0; i < expectedFiles.count; i++) {
        NSString *expectedFilename = expectedFiles[i];
        
        NSError *error = nil;
        NSData *extractedData = [archive extractDataFromFile:expectedFilename
                                                    progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                                        NSLog(@"Extracting, %f%% complete", percentDecompressed);
#endif
                                                    }
                                                       error:&error];
        
        XCTAssertNil(error, @"Error in extractData:error:");
        
        NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
        
        XCTAssertNotNil(extractedData, @"No data extracted");
        XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
        
        error = nil;
        NSData *dataFromFileInfo = [archive extractData:fileInfos[i]
                                               progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                                   NSLog(@"Extracting from file info, %f%% complete", percentDecompressed);
#endif
                                               }
                                                  error:&error];
        XCTAssertNil(error, @"Error extracting data by file info");
        XCTAssertTrue([expectedFileData isEqualToData:dataFromFileInfo], @"Extracted data from file info doesn't match original file");
    }
}

- (void)testExtractData_NoPassword
{
    NSArray *testArchives = @[@"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[testArchiveName]];
        
        NSError *error = nil;
        NSData *data = [archive extractDataFromFile:@"Test File A.txt"
                                           progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                               NSLog(@"Extracting, %f%% complete", percentDecompressed);
#endif
                                           }
                                              error:&error];
        
        XCTAssertNotNil(error, @"Extract data without password succeeded");
        XCTAssertNil(data, @"Data returned without password");
        XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
    }
}

- (void)testExtractData_InvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"Any file.txt"
                                       progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                           NSLog(@"Extracting, %f%% complete", percentDecompressed);
#endif
                                       }
                                          error:&error];
    
    XCTAssertNotNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNil(data, @"Data returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}


#pragma mark Perform on Files


- (void)testPerformOnFiles
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:password];
        
        __block NSUInteger fileIndex = 0;
        NSError *error = nil;
        
        [archive performOnFilesInArchive:
         ^(URKFileInfo *fileInfo, BOOL *stop) {
             NSString *expectedFilename = expectedFiles[fileIndex++];
             XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
         } error:&error];
        
        XCTAssertNil(error, @"Error iterating through files");
        XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
    }
}

- (void)testPerformOnFiles_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnFilesInArchive:
     ^(URKFileInfo *fileInfo, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}

- (void)testPerformOnFiles_Ordering
{
    NSArray *testFilenames = @[@"AAA.txt",
                               @"BBB.txt",
                               @"CCC.txt"];
    
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray *testFileURLs = [NSMutableArray array];

    // Touch test files
    [testFilenames enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL *stop) {
        NSURL *outputURL = [self.tempDirectory URLByAppendingPathComponent:filename];
        XCTAssertTrue([fm createFileAtPath:outputURL.path contents:nil attributes:nil], @"Failed to create test file: %@", filename);
        [testFileURLs addObject:outputURL];
    }];
    
    // Create RAR archive with test files, reversed
    NSURL *reversedArchiveURL = [self archiveWithFiles:testFileURLs.reverseObjectEnumerator.allObjects];

    NSError *error = nil;
    __block NSUInteger index = 0;

    URKArchive *archive = [URKArchive rarArchiveAtURL:reversedArchiveURL];
    [archive performOnFilesInArchive:^(URKFileInfo *fileInfo, BOOL *stop) {
        NSString *expectedFilename = testFilenames[index++];
        XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Archive files not iterated through in correct order");
    } error:&error];
}


#pragma mark Perform on Data


- (void)testPerformOnData
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:password];
        
        __block NSUInteger fileIndex = 0;
        NSError *error = nil;
        
        [archive performOnDataInArchive:
         ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
             NSString *expectedFilename = expectedFiles[fileIndex++];
             XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
             
             NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
             
             XCTAssertNotNil(fileData, @"No data extracted");
             XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
         } error:&error];
        
        XCTAssertNil(error, @"Error iterating through files");
        XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
    }
}

- (void)testPerformOnData_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
         
         NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
         
         XCTAssertNotNil(fileData, @"No data extracted");
         XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}

- (void)testPerformOnData_FileMoved
{
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];

    URKArchive *archive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"FileMoved"];
        
        NSError *renameError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
        XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    });
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testPerformOnData_FileDeleted
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
        XCTAssertNil(removeError, @"Error removing file: %@", removeError);
    });
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testPerformOnData_FileMovedBeforeBegin
{
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *archive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"FileMovedBeforeBegin"];
    
    NSError *renameError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
    XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testPerformOnData_Folder
{
    NSURL *testArchiveURL = self.testFileURLs[@"Folder Archive.rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSArray *expectedFiles = @[@"G070-Cliff", @"G070-Cliff/image.jpg"];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}


#pragma mark Extract Buffered Data


- (void)testExtractBufferedData
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    NSString *extractedFile = @"Test File B.jpg";
    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];
    
    NSError *error = nil;
    NSMutableData *reconstructedFile = [NSMutableData data];
    BOOL success = [archive extractBufferedDataFromFile:extractedFile
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [reconstructedFile appendBytes:dataChunk.bytes
                                                length:dataChunk.length];
                    }];
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    XCTAssertGreaterThan(reconstructedFile.length, 0, @"No data returned");
    
    NSData *originalFile = [NSData dataWithContentsOfURL:self.testFileURLs[extractedFile]];
    XCTAssertTrue([originalFile isEqualToData:reconstructedFile],
                  @"File extracted in buffer not returned correctly");
}

- (void)testExtractBufferedData_VeryLarge
{
    DTSendSignalFlag("Begin creating text file", DT_START_SIGNAL, TRUE);
    NSURL *largeTextFile = [self randomTextFileOfLength:1000000]; // Increase for a more dramatic test
    XCTAssertNotNil(largeTextFile, @"No large text file URL returned");
    DTSendSignalFlag("End creating text file", DT_END_SIGNAL, TRUE);

    DTSendSignalFlag("Begin archiving data", DT_START_SIGNAL, TRUE);
    NSURL *archiveURL = [self archiveWithFiles:@[largeTextFile]];
    XCTAssertNotNil(archiveURL, @"No archived large text file URL returned");
    DTSendSignalFlag("Begin archiving data", DT_END_SIGNAL, TRUE);

    NSURL *deflatedFileURL = [self.tempDirectory URLByAppendingPathComponent:@"DeflatedTextFile.txt"];
    BOOL createSuccess = [[NSFileManager defaultManager] createFileAtPath:deflatedFileURL.path
                                                                 contents:nil
                                                               attributes:nil];
    XCTAssertTrue(createSuccess, @"Failed to create empty deflate file");

    NSError *handleError = nil;
    NSFileHandle *deflated = [NSFileHandle fileHandleForWritingToURL:deflatedFileURL
                                                               error:&handleError];
    XCTAssertNil(handleError, @"Error creating a file handle");

    URKArchive *archive = [URKArchive rarArchiveAtURL:archiveURL];

    DTSendSignalFlag("Begin extracting buffered data", DT_START_SIGNAL, TRUE);

    NSError *error = nil;
    BOOL success = [archive extractBufferedDataFromFile:largeTextFile.lastPathComponent
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [deflated writeData:dataChunk];
                    }];
    
    DTSendSignalFlag("End extracting buffered data", DT_END_SIGNAL, TRUE);
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    
    [deflated closeFile];

    NSData *deflatedData = [NSData dataWithContentsOfURL:deflatedFileURL];
    NSData *fileData = [NSData dataWithContentsOfURL:largeTextFile];
    
    XCTAssertTrue([fileData isEqualToData:deflatedData], @"Data didn't restore correctly");
}


#pragma mark Is Password Protected


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


#pragma mark Validate Password


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


#pragma mark Various


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
            NSData *fileData = [archive extractDataFromFile:fileName
                                                   progress:^(CGFloat percentDecompressed) {
#if DEBUG
                                                       NSLog(@"Extracting, %f%% complete", percentDecompressed);
#endif
                                                   }
                                                      error:&error];
            XCTAssertNotNil(fileData);
            XCTAssertNil(error);
        }
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}

- (void)testMultiThreading {
    NSURL *largeArchiveURL_A = self.testFileURLs[@"Large Archive.rar"];
    NSURL *largeArchiveURL_B = [largeArchiveURL_A.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive 2.rar"];
    NSURL *largeArchiveURL_C = [largeArchiveURL_A.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive 3.rar"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *archiveBCopyError = nil;
    XCTAssertTrue([fm copyItemAtURL:largeArchiveURL_A toURL:largeArchiveURL_B error:&archiveBCopyError], @"Failed to copy archive B");
    XCTAssertNil(archiveBCopyError, @"Error copying archive B");
    
    NSError *archiveCCopyError = nil;
    XCTAssertTrue([fm copyItemAtURL:largeArchiveURL_A toURL:largeArchiveURL_C error:&archiveCCopyError], @"Failed to copy archive C");
    XCTAssertNil(archiveCCopyError, @"Error copying archive C");
    
    URKArchive *largeArchiveA = [URKArchive rarArchiveAtURL:largeArchiveURL_A];
    URKArchive *largeArchiveB = [URKArchive rarArchiveAtURL:largeArchiveURL_B];
    URKArchive *largeArchiveC = [URKArchive rarArchiveAtURL:largeArchiveURL_C];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveA performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveB performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveC performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}

- (void)testMultiThreading_SingleFile {
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *largeArchiveA = [URKArchive rarArchiveAtURL:largeArchiveURL];
    URKArchive *largeArchiveB = [URKArchive rarArchiveAtURL:largeArchiveURL];
    URKArchive *largeArchiveC = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveA performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveB performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveC performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}

- (void)testMultiThreading_SingleArchiveObject {
    NSURL *largeArchiveURL = self.testFileURLs[@"Large Archive.rar"];
    
    URKArchive *largeArchive = [URKArchive rarArchiveAtURL:largeArchiveURL];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}

- (void)testErrorIsCorrect
{
    NSError *error = nil;
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.corruptArchive];
    XCTAssertNil([archive listFilenames:&error], "Listing filenames in corrupt archive should return nil");
    XCTAssertNotNil(error, @"An error should be returned when listing filenames in a corrupt archive");
    XCTAssertNotNil(error.description, @"Error's description is nil");
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
                                                    overwrite:NO
                                                     progress:nil
                                                        error:&error];

    XCTAssertTrue(extractSuccess, @"Failed to extract archive");
    XCTAssertNil(extractFilesError, @"Error extracting archive: %@", extractFilesError);
}



#pragma mark - Helper Methods


- (NSURL *)urlOfTestFile:(NSString *)filename
{
    NSString *baseDirectory = @"Test Data";
    NSString *subPath = filename.stringByDeletingLastPathComponent;
    NSString *bundleSubdir = [baseDirectory stringByAppendingPathComponent:subPath];
    
    return [[NSBundle bundleForClass:[self class]] URLForResource:filename.lastPathComponent
                                                    withExtension:nil
                                                     subdirectory:bundleSubdir];
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

- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!\n";
    NSUInteger letterCount = letters.length;
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:numberOfCharacters];
    
    for (NSUInteger i = 0; i < numberOfCharacters; i++) {
        uint32_t charIndex = arc4random_uniform(letterCount);
        [randomString appendFormat:@"%C", [letters characterAtIndex:charIndex]];
    }
    
    NSURL *resultURL = [self.tempDirectory URLByAppendingPathComponent:
                        [NSString stringWithFormat:@"%@.txt", [[NSProcessInfo processInfo] globallyUniqueString]]];

    NSError *error = nil;
    [randomString writeToURL:resultURL atomically:YES encoding:NSUTF16StringEncoding error:&error];
    XCTAssertNil(error, @"Error opening file handle for text file creation: %@", error);
    
    return resultURL;
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs {
    NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    NSURL *rarExec = [[self.tempDirectory URLByAppendingPathComponent:@"bin"]
                      URLByAppendingPathComponent:@"rar"];
    NSURL *archiveURL = [[self.tempDirectory URLByAppendingPathComponent:uniqueString]
                         URLByAppendingPathExtension:@"rar"];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = rarExec.path;
    task.arguments = [@[@"a", @"-ep", archiveURL.path] arrayByAddingObjectsFromArray:[fileURLs valueForKeyPath:@"path"]];
    
    [task launch];
    [task waitUntilExit];
    
    if (task.terminationStatus != 0) {
        NSLog(@"Failed to create RAR archive");
        return nil;
    }
    
    return archiveURL;
}

- (NSUInteger)crcOfTestFile:(NSString *)filename {
    NSURL *fileURL = [self urlOfTestFile:filename];
    NSData *fileContents = [[NSFileManager defaultManager] contentsAtPath:[fileURL path]];
    return crc32(0, fileContents.bytes, fileContents.length);
}



@end
