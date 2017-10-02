//
//  FirstVolumeTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 2/9/17.
//
//

#import "URKArchiveTestCase.h"

@interface FirstVolumeTests : URKArchiveTestCase @end

@interface URKArchive (Tests)

// It's a private class method
+ (NSURL *)firstVolumeURL:(NSURL *)volumeURL;

@end

@implementation FirstVolumeTests

- (void)testSingleVolume {
    NSURL *onlyVolumeArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:onlyVolumeArchiveURL];
    
    XCTAssertNotNil(returnedFirstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(returnedFirstVolumeURL, onlyVolumeArchiveURL, @"URL changed even though it's a single volume archive");
}

- (void)testMultipleVolume_UseFirstVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"FirstVolumeTests-testMultipleVolume_UseFirstVolume.rar"];
    NSURL *firstVolumeURL = volumeURLs.firstObject;
    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:firstVolumeURL];

    XCTAssertNotNil(returnedFirstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(returnedFirstVolumeURL, firstVolumeURL, @"URL changed even though it was initialized with the first volume");
}

- (void)testMultipleVolume_UseMiddleVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_UseFirstVolume.rar"];
    NSURL *firstVolumeURL = volumeURLs.firstObject;
    NSURL *thirdVolumeURL = volumeURLs[2];

    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:thirdVolumeURL];

    XCTAssertNotNil(returnedFirstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(returnedFirstVolumeURL.absoluteString, firstVolumeURL.absoluteString, @"Incorrect URL returned as first volume");
}

- (void)testMultipleVolume_UseFirstVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"FirstVolumeTests-testMultipleVolume_UseFirstVolume_OldNamingScheme.rar"];
    NSURL *firstVolumeURL = volumeURLs.firstObject;
    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:firstVolumeURL];
    
    XCTAssertNotNil(returnedFirstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(returnedFirstVolumeURL, firstVolumeURL, @"URL changed even though it was initialized with the first volume");
}

- (void)testMultipleVolume_UseMiddleVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"FirstVolumeTests-testMultipleVolume_UseMiddleVolume_OldNamingScheme.rar"];
    NSURL *firstVolumeURL = volumeURLs.firstObject;
    NSURL *thirdVolumeURL = volumeURLs[2];
    
    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:thirdVolumeURL];
    
    XCTAssertNotNil(returnedFirstVolumeURL, @"No URL returned");
    XCTAssertEqualObjects(returnedFirstVolumeURL.absoluteString, firstVolumeURL.absoluteString, @"Incorrect URL returned as first volume");
}

- (void)testMultipleVolume_FirstVolumeMissing {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_FirstVolumeMissing.rar"];
    
    NSError *deleteError = nil;
    [[NSFileManager defaultManager] removeItemAtURL:volumeURLs.firstObject
                                              error:&deleteError];
    XCTAssertNil(deleteError, @"Error deleting first volume of archive");
    
    NSURL *firstVolumeURL = volumeURLs.firstObject;
    NSURL *returnedFirstVolumeURL = [URKArchive firstVolumeURL:firstVolumeURL];
    
    XCTAssertNil(returnedFirstVolumeURL, @"First volume URL returned when it does not exist");
}

@end
