//
//  PerformOnFilesTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

@interface PerformOnFilesTests : URKArchiveTestCase

@end

@implementation PerformOnFilesTests

- (void)testPerformOnFiles
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
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

- (void)testPerformOnFiles_ModifiedCRC
{
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *password = nil;
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
    
    __block BOOL blockCalled = NO;
    NSError *error = nil;
    
    [archive performOnFilesInArchive:
     ^(URKFileInfo *fileInfo, BOOL *stop) {
         blockCalled = YES;
     } error:&error];
    
    XCTAssertNotNil(error, @"Error iterating through files");
    XCTAssertFalse(blockCalled);
}

- (void)testPerformOnFiles_ModifiedCRC_MismatchesIgnored
{
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *password = nil;
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
    
    BOOL checkIntegritySuccess = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
        return YES;
    }];
    
    XCTAssertTrue(checkIntegritySuccess, @"Data integrity check failed for archive with modified CRC, when instructed to ignore");
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnFilesInArchive:
     ^(URKFileInfo *fileInfo, BOOL *stop) {
         XCTAssertEqual(fileIndex++, 0, @"performOnFilesInArchive called too many times");
         XCTAssertEqualObjects(fileInfo.filename, @"README.md");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
}

- (void)testPerformOnFiles_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
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

#if !TARGET_OS_IPHONE
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
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:reversedArchiveURL error:nil];
    [archive performOnFilesInArchive:^(URKFileInfo *fileInfo, BOOL *stop) {
        NSString *expectedFilename = testFilenames[index++];
        XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Archive files not iterated through in correct order");
    } error:&error];
}
#endif

@end
