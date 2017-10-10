//
//  CheckDataTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 10/6/17.
//

#import "URKArchiveTestCase.h"

@interface CheckDataTests : URKArchiveTestCase @end

@implementation CheckDataTests

#pragma mark - checkDataIntegrity

- (void)testCheckDataIntegrity {
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing data integrity of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        BOOL success = [archive checkDataIntegrity];
        XCTAssertTrue(success, @"Data integrity check failed for %@", testArchiveName);
    }
}

- (void)testCheckDataIntegrity_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrity];
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
}

- (void)testCheckDataIntegrity_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrity];
    XCTAssertFalse(success, @"Data integrity check passed for archive with a modified CRC");
}

#pragma mark - checkDataIntegrityOfFile

- (void)testCheckDataIntegrityForFile {
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing data integrity of file in archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        NSError *listFilenamesError = nil;
        NSArray <NSString*> *filenames = [archive listFilenames:&listFilenamesError];
        
        XCTAssertNotNil(filenames, @"No file info returned for %@", testArchiveName);
        XCTAssertNil(listFilenamesError, @"Error returned for %@: %@", testArchiveName, listFilenamesError);
        
        NSString *firstFilename = filenames.firstObject;
        BOOL success = [archive checkDataIntegrityOfFile:firstFilename];
        
        XCTAssertTrue(success, @"Data integrity check failed for %@ in %@", firstFilename, testArchiveName);
    }
}

- (void)testCheckDataIntegrityForFile_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrityOfFile:@"README.md"];
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
}

- (void)testCheckDataIntegrityForFile_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrityOfFile:@"README.md"];
    XCTAssertFalse(success, @"Data integrity check passed for archive with modified CRC");
}

@end
