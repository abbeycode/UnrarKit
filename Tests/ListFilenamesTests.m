//
//  ListFilenamesTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import <Cocoa/Cocoa.h>
#import "URKArchiveTestCase.h"

@interface ListFilenamesTests : URKArchiveTestCase

@end

@implementation ListFilenamesTests


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

- (void)testListFilenames_RAR5
{
    NSArray *expectedFiles = @[@"yohoho_ws.txt",
                               @"nopw.txt"];
    
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive (RAR5).rar"];
    URKArchive *archive = [URKArchive rarArchiveAtURL:testArchiveURL];
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFilenames:&error];
    
    XCTAssertNil(error, @"Error returned by listFilenames");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFiles.count,
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


@end
