//
//  URKArchiveTestCase.h
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import <XCTest/XCTest.h>
#import <UnrarKit/UnrarKit.h>


@interface URKArchiveTestCase : XCTestCase

@property BOOL testFailed;

@property NSURL *tempDirectory;
@property NSMutableDictionary *testFileURLs;
@property NSMutableDictionary *unicodeFileURLs;
@property NSURL *corruptArchive;


- (NSURL *)urlOfTestFile:(NSString *)filename;
- (NSString *)randomDirectoryName;
- (NSString *)randomDirectoryWithPrefix:(NSString *)prefix;
- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters;
- (NSUInteger)crcOfTestFile:(NSString *)filename;

// Mac Only

#if !TARGET_OS_IPHONE
- (NSInteger)numberOfOpenFileHandles;
- (NSURL *)archiveWithFiles:(NSArray *)fileURLs;
#endif

@end
