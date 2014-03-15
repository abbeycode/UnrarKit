//
//  Unrar4iOS_Tests.m
//  Unrar4iOS Tests
//
//  Created by Dov Frankel on 3/13/14.
//

#import <XCTest/XCTest.h>
#import "Unrar4iOS.h"

@interface Unrar4iOS_Tests : XCTestCase

@property BOOL testFailed;

@property (copy) NSURL *tempDirectory;
@property (retain) NSMutableDictionary *testFileURLs;

@end

@implementation Unrar4iOS_Tests



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
    
    self.testFailed = NO;
    self.testFileURLs = [[NSMutableDictionary alloc] init];
    self.tempDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:uniqueName]
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


- (void)testUnrarListFiles
{
    NSArray *testArchives = @[@"Test Archive.rar", @"Test Archive (Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];

        Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
        [unrar unrarOpenFile:testArchiveURL.path];
        
        NSArray *filesInArchive = [unrar unrarListFiles];
        
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

- (void)testUnrarListFilesWithHeaderPassword
{
    NSArray *testArchives = @[@"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];

        Unrar4iOS *unrarNoPassword = [[Unrar4iOS alloc] init];
        [unrarNoPassword unrarOpenFile:testArchiveURL.path];
        
        NSArray *filesInArchive = [unrarNoPassword unrarListFiles];
        
        XCTAssertNotNil(filesInArchive, @"No list of files returned");
        XCTAssertEqual(filesInArchive.count, (NSUInteger)0, @"File list returned, when no password specified");
        
        
        Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
        [unrar unrarOpenFile:testArchiveURL.path withPassword:@"password"];
        
        filesInArchive = nil;
        filesInArchive = [unrar unrarListFiles];
        
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

- (void)testUnrarFiles
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
        Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
        [unrar unrarOpenFile:testArchiveURL.path withPassword:password];
        
        BOOL success = [unrar unrarFileTo:extractURL.path overWrite:NO];
        
        XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
        
        NSError *error = nil;
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

- (void)testExtractStream
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
        NSLog(@"Testing extraction of steam from archive %@", testArchiveName);

        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
        [unrar unrarOpenFile:testArchiveURL.path withPassword:password];
        
        for (NSInteger i = 0; i < expectedFiles.count; i++) {
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);
            
            NSData *extractedData = [unrar extractStream:expectedFilename];
            NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
            
            XCTAssertNotNil(extractedData, @"No data extracted");
            XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
        }
    }
}

- (void)testUnrarCloseFile
{
    Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
    BOOL result = [unrar unrarCloseFile];
    
    XCTAssertTrue(result, @"Close file returned NO");
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


@end
