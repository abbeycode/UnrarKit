//
//  ExtractionPerformanceTests.m
//  UnrarKit
//
//  Created by Huikai Chen  on 2020/4/27.
//

#import "URKArchiveTestCase.h"

@interface ExtractionPerformanceTests : URKArchiveTestCase @end

@implementation ExtractionPerformanceTests

#pragma mark - Extraction - Old way, iterate and locate the entry data

- (void)extractEntriesWithOldWay:(URKArchive *)archive
                       fileNames:(NSArray<NSString *>*)fileNames {
    for (int i = 0 ; i < fileNames.count; i++) {
        NSString *filename = [fileNames objectAtIndex:i];

        NSMutableData *reconstructedFile = [NSMutableData data];
        [archive extractBufferedDataFromFile:filename
                                                      error:nil
                                                     action:
                                                             ^(NSData *dataChunk, CGFloat percentDecompressed) {
                                                                 [reconstructedFile appendBytes:dataChunk.bytes
                                                                                         length:dataChunk.length];
                                                             }];
    }
}

#pragma mark - Extraction - New way, seek directly to entry's offset

- (void)extractEntriesWithNewWay:(URKArchive *)archive
                       fileInfos:(NSArray<URKFileInfo *>*)fileInfos {
   for (int i = 0 ; i < fileInfos.count; i++) {
       URKFileInfo *fileInfo = [fileInfos objectAtIndex:i];

       NSMutableData *reconstructedFile = [NSMutableData data];
       [archive extractBufferedDataByOffsetOf:fileInfo
                                                   ignoreCRC: NO
                                                     error:nil
                                                    action:
                                                            ^(NSData *dataChunk, CGFloat percentDecompressed) {
                                                                [reconstructedFile appendBytes:dataChunk.bytes
                                                                                        length:dataChunk.length];
                                                            }];
   }
}

#pragma mark - 100 small files - old way

- (void)testSpeedWithIterateAndLocateMethod100 {
    NSString *testArchiveName = @"small files/100.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileNames = [archive listFilenames:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithOldWay:archive fileNames:fileNames];
    }];
}


#pragma mark - 100 small files - new way

- (void)testSpeedWithSeekToOffsetMethod100 {
    NSString *testArchiveName = @"small files/100.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileInfos = [archive listFileInfo:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithNewWay:archive fileInfos:fileInfos];
    }];
}


#pragma mark - 200 small files - old way

- (void)testSpeedWithIterateAndLocateMethod200 {
    NSString *testArchiveName = @"small files/200.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileNames = [archive listFilenames:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithOldWay:archive fileNames:fileNames];
    }];
}


#pragma mark - 200 small files - new way

- (void)testSpeedWithSeekToOffsetMethod200 {
    NSString *testArchiveName = @"small files/200.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileInfos = [archive listFileInfo:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithNewWay:archive fileInfos:fileInfos];
    }];
}


#pragma mark - 1k small files - old way

- (void)testSpeedWithIterateAndLocateMethod1K {
//    NSString *testArchiveName = @"small files/1k.rar";
//    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
//
//    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
//    NSArray *fileNames = [archive listFilenames:nil];
    
    // It's pretty slow, so I comment it out, can enable it if u got time to test haha :P
//    [self measureBlock:^{
//        [self extractEntriesWithOldWay:archive fileNames:fileNames];
//    }];
}


#pragma mark - 1k small files - new way

- (void)testSpeedWithSeekToOffsetMethod1K {
    NSString *testArchiveName = @"small files/1k.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileInfos = [archive listFileInfo:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithNewWay:archive fileInfos:fileInfos];
    }];
}


#pragma mark - 2k small files - old way

- (void)testSpeedWithIterateAndLocateMethod2K {
//    NSString *testArchiveName = @"small files/2k.rar";
//    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
//
//    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
//    NSArray *fileNames = [archive listFilenames:nil];
    
    // It's pretty slow, so I comment it out, can enable it if u got time to test haha :P
//    [self measureBlock:^{
//        [self extractEntriesWithOldWay:archive fileNames:fileNames];
//    }];
}


#pragma mark - 2k small files - new way

- (void)testSpeedWithSeekToOffsetMethod2K {
    NSString *testArchiveName = @"small files/2k.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"" error:nil];
    NSArray *fileInfos = [archive listFileInfo:nil];
    
    [self measureBlock:^{
        [self extractEntriesWithNewWay:archive fileInfos:fileInfos];
    }];
}


@end
