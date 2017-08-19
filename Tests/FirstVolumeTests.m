//
//  FirstVolumeTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 2/9/17.
//
//

#import "URKArchiveTestCase.h"

@interface FirstVolumeTests : URKArchiveTestCase

@end

@implementation FirstVolumeTests

- (void)testSingleVolume {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];
    
    XCTAssertNotNil(firstVolumePath, @"No path returned");
    XCTAssertTrue([firstVolumePath hasSuffix:testArchiveURL.path], @"Wrong URL returned (%@)", firstVolumePath);
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    
    XCTAssertNotNil(firstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(firstVolumeURL.path, firstVolumePath, @"Path and URL don't match each other");
}

- (void)testMultipleVolume_UseFirstVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"FirstVolumeTests-testMultipleVolume_UseFirstVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs.firstObject error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];

    XCTAssertNotNil(firstVolumePath, @"No path returned");
    XCTAssertTrue([firstVolumePath hasSuffix:volumeURLs.firstObject.path], @"Wrong URL returned (%@)", firstVolumePath);
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    
    XCTAssertNotNil(firstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(firstVolumeURL.path, firstVolumePath, @"Path and URL don't match each other");
}

- (void)testMultipleVolume_UseMiddleVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_UseFirstVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs[2] error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];
    
    XCTAssertNotNil(firstVolumePath, @"No path returned");
    XCTAssertTrue([firstVolumePath hasSuffix:volumeURLs.firstObject.path], @"Wrong URL returned (%@)", firstVolumePath);
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    
    XCTAssertNotNil(firstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(firstVolumeURL.path, firstVolumePath, @"Path and URL don't match each other");
}

- (void)testMultipleVolume_UseFirstVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"FirstVolumeTests-testMultipleVolume_UseFirstVolume_OldNamingScheme.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs.firstObject error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];
    
    XCTAssertNotNil(firstVolumePath, @"No path returned");
    XCTAssertTrue([firstVolumePath hasSuffix:volumeURLs.firstObject.path], @"Wrong URL returned (%@)", firstVolumePath);
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    
    XCTAssertNotNil(firstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(firstVolumeURL.path, firstVolumePath, @"Path and URL don't match each other");
}

- (void)testMultipleVolume_UseMiddleVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"FirstVolumeTests-testMultipleVolume_UseMiddleVolume_OldNamingScheme.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs[2] error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];
    
    XCTAssertNotNil(firstVolumePath, @"No path returned");
    XCTAssertTrue([firstVolumePath hasSuffix:volumeURLs.firstObject.path], @"Wrong URL returned (%@)", firstVolumePath);
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    
    XCTAssertNotNil(firstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(firstVolumeURL.path, firstVolumePath, @"Path and URL don't match each other");
}

- (void)testMultipleVolume_FirstVolumeMissing {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_FirstVolumeMissing.rar"];
    
    NSError *deleteError = nil;
    [[NSFileManager defaultManager] removeItemAtURL:volumeURLs.firstObject
                                              error:&deleteError];
    XCTAssertNil(deleteError, @"Error deleting first volume of archive");
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs[2] error:nil];
    
    NSString *firstVolumePath = [archive firstVolumePath];
    XCTAssertNil(firstVolumePath, @"First volume path returned when it does not exist");
    
    NSURL *firstVolumeURL = [archive firstVolumeURL];
    XCTAssertNil(firstVolumeURL, @"First volume URL returned when it does not exist");
}

@end
