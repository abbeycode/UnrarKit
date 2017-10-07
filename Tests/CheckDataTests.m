//
//  CheckDataTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 10/6/17.
//

#import "URKArchiveTestCase.h"

@interface CheckDataTests : URKArchiveTestCase @end

@implementation CheckDataTests

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
        
        NSError *dataCheckError = nil;
        BOOL success = [archive checkDataIntegrity:&dataCheckError];
        
        XCTAssertTrue(success, @"Data integrity check failed for %@", testArchiveName);
        XCTAssertNil(dataCheckError, @"Error returned by checkDataIntegrity: %@", dataCheckError);
    }
}

- (void)testCheckDataIntegrity_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *dataCheckError = nil;
    BOOL success = [archive checkDataIntegrity:&dataCheckError];
    
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
    XCTAssertNotNil(dataCheckError, @"No error returned by checkDataIntegrity");
}



- (void)testCheckDataIntegrity_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *dataCheckError = nil;
    BOOL success = [archive checkDataIntegrity:&dataCheckError];

    XCTAssertFalse(success, @"Data integrity check passed for archive with a modified CRC");
    XCTAssertNotNil(dataCheckError, @"No error returned by checkDataIntegrity");
}

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
        NSError *dataCheckError = nil;
        BOOL success = [archive checkDataIntegrityOfFile:firstFilename error:&dataCheckError];
        
        XCTAssertTrue(success, @"Data integrity check failed for %@ in %@", firstFilename, testArchiveName);
        XCTAssertNil(dataCheckError, @"Error returned by checkDataIntegrity: %@", dataCheckError);
    }
}

- (void)testCheckDataIntegrityForFile_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSString *filename = @"README.md";
    NSError *dataCheckError = nil;
    BOOL success = [archive checkDataIntegrityOfFile:filename error:&dataCheckError];

    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
    XCTAssertNotNil(dataCheckError, @"Error not returned by checkDataIntegrity");
}

- (void)testCheckDataIntegrityForFile_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSString *filename = @"README.md";
    NSError *dataCheckError = nil;
    BOOL success = [archive checkDataIntegrityOfFile:filename error:&dataCheckError];
    
    XCTAssertFalse(success, @"Data integrity check passed for archive with modified CRC");
    XCTAssertNotNil(dataCheckError, @"Error not returned by checkDataIntegrity");
}

@end
