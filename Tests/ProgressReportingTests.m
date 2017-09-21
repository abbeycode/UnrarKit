//
//  ProgressReportingTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 9/19/17.
//
//

#import <XCTest/XCTest.h>
#import "URKArchiveTestCase.h"


@interface ProgressReportingTests : URKArchiveTestCase

@property NSMutableArray<NSNumber*> *extractFilesProgressesReported;
@property NSMutableArray<NSString*> *descriptionsReported;
@property NSMutableArray<NSString*> *additionalDescriptionsReported;

@end

static void *ExtractFilesContext = &ExtractFilesContext;

@implementation ProgressReportingTests


- (void)setUp {
    [super setUp];

    self.extractFilesProgressesReported = [NSMutableArray array];
    self.descriptionsReported = [NSMutableArray array];
    self.additionalDescriptionsReported = [NSMutableArray array];
}

- (void)testProgressReporting_ExtractFiles_FractionCompleted
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&error];
    
    XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFilesProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.000315,
                                                @0.533568,
                                                @1.0];
    
    XCTAssertEqual(self.extractFilesProgressesReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.extractFilesProgressesReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.00001f, @"Incorrect progress reported at index %ld", i);
    }
}

- (void)testProgressReporting_ExtractFiles_Description
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedDescription));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&error];
    
    XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    NSUInteger expectedProgressUpdates = 3;
    NSArray<NSString *>*expectedDescriptions = @[@"Processing “Test File A.txt”",
                                                 @"Processing “Test File B.jpg”",
                                                 @"Processing “Test File C.m4a”"];
    
    XCTAssertEqual(self.descriptionsReported.count, expectedProgressUpdates, @"Incorrect number of current file info updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        NSString *expectedDescription = expectedDescriptions[i];
        NSString *actualDescription = self.descriptionsReported[i];
        
        XCTAssertEqualObjects(actualDescription, expectedDescription, @"Unexpected description %ld", i);
    }
}

- (void)testProgressReporting_ExtractFiles_AdditionalDescription
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedAdditionalDescription));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&error];
    
    XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSString *>*expectedAdditionalDescriptions = @[@"Zero KB of 105 KB",
                                                           @"33 bytes of 105 KB",
                                                           @"56 KB of 105 KB",
                                                           @"105 KB of 105 KB"];
    
    XCTAssertEqual(self.additionalDescriptionsReported.count, expectedProgressUpdates, @"Incorrect number of current file info updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        NSString *expectedAdditionalDescription = expectedAdditionalDescriptions[i];
        NSString *actualAdditionalDescription = self.additionalDescriptionsReported[i];
        
        XCTAssertEqualObjects(actualAdditionalDescription, expectedAdditionalDescription, @"Unexpected description %ld", i);
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context == ExtractFilesContext) {
        NSProgress *progress = object;
        
        [self.extractFilesProgressesReported addObject:@(progress.fractionCompleted)];
        [self.descriptionsReported addObject:progress.localizedDescription];
        [self.additionalDescriptionsReported addObject:progress.localizedAdditionalDescription];
    }
}

@end
