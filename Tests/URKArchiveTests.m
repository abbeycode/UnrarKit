//
//  URKArchiveTests.m
//  UnrarKit Tests
//
//

#import <XCTest/XCTest.h>
#import <UnrarKit/URKArchive.h>

@interface URKArchiveTests : XCTestCase

@property BOOL testFailed;

@property (copy) NSURL *tempDirectory;
@property (retain) NSMutableDictionary *testFileURLs;
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
    
    NSArray *testFiles = @[@"Test Archive.rar",
                           @"Test Archive (Password).rar",
                           @"Test Archive (Header Password).rar",
                           @"Test File A.txt",
                           @"Test File B.jpg",
                           @"Test File C.m4a"];
    
    NSString *tempDirSubtree = [@"UnrarKitTest" stringByAppendingPathComponent:uniqueName];
    
    self.testFailed = NO;
    self.testFileURLs = [[NSMutableDictionary alloc] init];
    self.tempDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempDirSubtree]
                                    isDirectory:YES];

    NSLog(@"Temp directory: %@", self.tempDirectory);
    
    [fm createDirectoryAtURL:self.tempDirectory
 withIntermediateDirectories:YES
                  attributes:nil
                       error:&error];
    
    XCTAssertNil(error, @"Failed to create temp directory: %@", self.tempDirectory);

    for (NSString *file in testFiles) {
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
        
        [self.testFileURLs setObject:destinationURL forKey:file];
    }
    
    // Make a "corrupt" rar file
    NSURL *m4aFileURL = [self urlOfTestFile:testFiles[5]];
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


- (void)testListFiles
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
        NSArray *filesInArchive = [archive listFiles:&error];
        
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

- (void)testListFilesWithHeaderPassword
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
        NSArray *filesInArchive = [archiveNoPassword listFiles:&error];
        
        XCTAssertNotNil(error, @"No error returned by unrarListFiles (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL password:@"password"];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFiles:&error];
        
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

- (void)testListFilesWithoutPassword
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test Archive (Header Password).rar"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFiles:&error];
    
    XCTAssertNotNil(error, @"List without password succeeded");
    XCTAssertNil(files, @"List returned without password");
    XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
}

- (void)testListFilesForInvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSArray *files = [archive listFiles:&error];
    
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

- (void)testExtractFilesWithoutPassword
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

- (void)testExtractFilesForInvalidArchive
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

- (void)testExtractDataWithoutPassword
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

- (void)testExtractDataForInvalidArchive
{
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.testFileURLs[@"Test File A.txt"]];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"Any file.txt" error:&error];
    
    XCTAssertNotNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNil(data, @"Data returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
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
        
        NSArray *fileList = [archive listFiles:&error];
        XCTAssertNotNil(fileList);
        
        for (NSString *fileName in fileList) {
            NSData *fileData = [archive extractDataFromFile:fileName error:&error];
            XCTAssertNotNil(fileData);
            XCTAssertNil(error);
        }
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 1, @"File descriptors were left open");
}

- (void)testErrorIsCorrect
{
    NSError *error = nil;
    URKArchive *archive = [URKArchive rarArchiveAtURL:self.corruptArchive];
    XCTAssertNil([archive listFiles:&error], "Listing files in corrupt archive should return nil");
    XCTAssertNotNil(error, @"An error should be returned when listing files in a corrupt archive");
    XCTAssertNotNil(error.description, @"Error's description is nil");
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


@end
