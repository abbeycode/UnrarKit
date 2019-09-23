//
//  ExtractBufferedDataTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

#import <sys/kdebug_signpost.h>
enum SignPostCode: uint {   // Use to reference in Instruments (http://stackoverflow.com/a/39416673/105717)
    SignPostCodeCreateTextFile = 0,
    SignPostCodeArchiveData = 1,
    SignPostCodeExtractData = 2,
};

enum SignPostColor: uint {  // standard color scheme for signposts in Instruments
    SignPostColorBlue = 0,
    SignPostColorGreen = 1,
    SignPostColorPurple = 2,
    SignPostColorOrange = 3,
    SignPostColorRed = 4,
};


@interface ExtractBufferedDataTests : URKArchiveTestCase @end

@implementation ExtractBufferedDataTests

- (void)testExtractBufferedData
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    NSString *extractedFile = @"Test File B.jpg";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
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

- (void)testExtractBufferedData_ModifiedCRC
{
    NSURL *archiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *extractedFile = @"README.md";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
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
    
    XCTAssertFalse(success, @"Failed to read buffered data");
    XCTAssertNotNil(error, @"Error reading buffered data");
    
    NSData *originalFile = [NSData dataWithContentsOfURL:self.testFileURLs[extractedFile]];
    XCTAssertTrue([originalFile isEqualToData:reconstructedFile],
                  @"File extracted in buffer not returned correctly");
}

- (void)testExtractBufferedData_ModifiedCRC_IgnoringMismatches
{
    NSURL *archiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *extractedFile = @"README.md";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    BOOL checkIntegritySuccess = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
        return YES;
    }];
    
    XCTAssertTrue(checkIntegritySuccess, @"Data integrity check failed for archive with modified CRC, when instructed to ignore");
    
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

#if !TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200
- (void)testExtractBufferedData_VeryLarge
{
    kdebug_signpost_start(SignPostCodeCreateTextFile, 0, 0, 0, SignPostColorBlue);
    NSURL *largeTextFile = [self randomTextFileOfLength:1000000]; // Increase for a more dramatic test
    XCTAssertNotNil(largeTextFile, @"No large text file URL returned");
    kdebug_signpost_end(SignPostCodeCreateTextFile, 0, 0, 0, SignPostColorBlue);
    
    kdebug_signpost_start(SignPostCodeArchiveData, 0, 0, 0, SignPostColorGreen);
    NSURL *archiveURL = [self archiveWithFiles:@[largeTextFile]];
    XCTAssertNotNil(archiveURL, @"No archived large text file URL returned");
    kdebug_signpost_end(SignPostCodeArchiveData, 0, 0, 0, SignPostColorGreen);
    
    NSURL *deflatedFileURL = [self.tempDirectory URLByAppendingPathComponent:@"DeflatedTextFile.txt"];
    BOOL createSuccess = [[NSFileManager defaultManager] createFileAtPath:deflatedFileURL.path
                                                                 contents:nil
                                                               attributes:nil];
    XCTAssertTrue(createSuccess, @"Failed to create empty deflate file");
    
    NSError *handleError = nil;
    NSFileHandle *deflated = [NSFileHandle fileHandleForWritingToURL:deflatedFileURL
                                                               error:&handleError];
    XCTAssertNil(handleError, @"Error creating a file handle");
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    kdebug_signpost_start(SignPostCodeExtractData, 0, 0, 0, SignPostColorPurple);
    
    NSError *error = nil;
    BOOL success = [archive extractBufferedDataFromFile:largeTextFile.lastPathComponent
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [deflated writeData:dataChunk];
                    }];
    
    kdebug_signpost_end(SignPostCodeExtractData, 0, 0, 0, SignPostColorPurple);
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    
    [deflated closeFile];
    
    NSData *deflatedData = [NSData dataWithContentsOfURL:deflatedFileURL];
    NSData *fileData = [NSData dataWithContentsOfURL:largeTextFile];
    
    XCTAssertTrue([fileData isEqualToData:deflatedData], @"Data didn't restore correctly");
}
#endif

@end
