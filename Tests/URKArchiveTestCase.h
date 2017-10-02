//
//  URKArchiveTestCase.h
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "TargetConditionals.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@import XCTest;
@import UnrarKit;


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
- (NSURL *)largeArchiveURL;
- (NSInteger)numberOfOpenFileHandles;
- (NSURL *)archiveWithFiles:(NSArray *)fileURLs;
#endif

@end
