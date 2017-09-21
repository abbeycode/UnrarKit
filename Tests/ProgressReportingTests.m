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

@property NSMutableArray<NSNumber*> *fractionsCompletedReported;
@property NSMutableArray<NSString*> *descriptionsReported;
@property NSMutableArray<NSString*> *additionalDescriptionsReported;

@end

static void *ExtractFilesContext = &ExtractFilesContext;
static void *OtherContext = &OtherContext;

@implementation ProgressReportingTests


- (void)setUp {
    [super setUp];

    self.fractionsCompletedReported = [NSMutableArray array];
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
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:progress:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFilesProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.000315,
                                                @0.533568,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
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
    
    [self.descriptionsReported removeAllObjects];
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:progress:error:");
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
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                  progress:nil
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:progress:error:");
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

- (void)testProgressReporting_PerformOnFiles {
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *performProgress = [NSProgress progressWithTotalUnitCount:1];
    [performProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [performProgress addObserver:self
                      forKeyPath:observedSelector
                         options:NSKeyValueObservingOptionInitial
                         context:OtherContext];
    
    NSError *performError = nil;
    BOOL success = [archive performOnFilesInArchive:
                    ^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {} error:&performError];
    
    XCTAssertNil(performError, @"Error returned by performOnFilesInArchive:error:");
    XCTAssertTrue(success, @"Unrar failed to perform operation on files of archive");
    
    [performProgress resignCurrent];
    [performProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(performProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.333333,
                                                @0.666666,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", i);
    }
}

- (void)testProgressReporting_PerformOnData {
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *performProgress = [NSProgress progressWithTotalUnitCount:1];
    [performProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [performProgress addObserver:self
                      forKeyPath:observedSelector
                         options:NSKeyValueObservingOptionInitial
                         context:OtherContext];
    
    NSError *performError = nil;
    BOOL success = [archive performOnDataInArchive:
                    ^(URKFileInfo * _Nonnull fileInfo, NSData * _Nonnull fileData, BOOL * _Nonnull stop) {}
                                             error:&performError];
    
    XCTAssertNil(performError, @"Error returned by performOnDataInArchive:error:");
    XCTAssertTrue(success, @"Unrar failed to perform operation on data of archive");
    
    [performProgress resignCurrent];
    [performProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(performProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.000315,
                                                @0.533568,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", i);
    }
}


#pragma mark - Mac-only tests


#if !TARGET_OS_IPHONE
- (void)testProgressReporting_ExtractData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:OtherContext];
    
    NSError *extractError = nil;
    NSData *data = [archive extractDataFromFile:firstFile
                                       progress:nil
                                          error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractDataFromFile:progress:error:");
    XCTAssertNotNil(data, @"Unrar failed to extract large archive");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFileProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.6990074,
                                                @0.6990504,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", i);
    }
}

- (void)testProgressReporting_ExtractBufferedData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:OtherContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractBufferedDataFromFile:firstFile
                                                  error:&extractError
                                                 action:^(NSData * _Nonnull dataChunk, CGFloat percentDecompressed) {}];
    
    XCTAssertNil(extractError, @"Error returned by extractDataFromFile:progress:error:");
    XCTAssertTrue(success, @"Unrar failed to extract large archive into buffer");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFileProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.6990074,
                                                @0.6990504,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", i);
    }
}
#endif


#pragma mark - Private methods


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    NSProgress *progress;
   
    if ([object isKindOfClass:[NSProgress class]]) {
        progress = object;
        [self.fractionsCompletedReported addObject:@(progress.fractionCompleted)];
    }
    
    if (context == ExtractFilesContext) {
        [self.descriptionsReported addObject:progress.localizedDescription];
        [self.additionalDescriptionsReported addObject:progress.localizedAdditionalDescription];
    }
}

@end
