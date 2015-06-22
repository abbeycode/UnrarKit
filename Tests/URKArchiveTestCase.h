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
- (NSInteger)numberOfOpenFileHandles;
- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters;
- (NSURL *)archiveWithFiles:(NSArray *)fileURLs;
- (NSUInteger)crcOfTestFile:(NSString *)filename;

@end
