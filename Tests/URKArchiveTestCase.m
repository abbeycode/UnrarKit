//
//  URKArchiveTestCase.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "URKArchiveTestCase.h"

#import <zlib.h>



static NSURL *originalLargeArchiveURL;


@implementation URKArchiveTestCase


#pragma mark - Test Management


- (void)setUp
{
    [super setUp];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *uniqueName = [self randomDirectoryName];
    NSError *error = nil;
    
    NSArray *testFiles = @[@"Test Archive.rar",
                           @"Test Archive (Password).rar",
                           @"Test Archive (Header Password).rar",
                           @"Test Archive (RAR5, Password).rar",
                           @"Test Archive (RAR5).rar",
                           @"Folder Archive.rar",
                           @"Test File A.txt",
                           @"Test File B.jpg",
                           @"Test File C.m4a",
                           @"bin/rar"];
    
    NSArray *unicodeFiles = @[@"Ⓣest Ⓐrchive.rar",
                              @"Test File Ⓐ.txt",
                              @"Test File Ⓑ.jpg",
                              @"Test File Ⓒ.m4a"];
    
    NSString *tempDirSubtree = [@"UnrarKitTest" stringByAppendingPathComponent:uniqueName];
    
    self.testFailed = NO;
    self.testFileURLs = [[NSMutableDictionary alloc] init];
    self.unicodeFileURLs = [[NSMutableDictionary alloc] init];
    self.tempDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempDirSubtree]
                                    isDirectory:YES];
    
    NSLog(@"Temp directory: %@", self.tempDirectory);
    
    [fm createDirectoryAtURL:self.tempDirectory
 withIntermediateDirectories:YES
                  attributes:nil
                       error:&error];
    
    XCTAssertNil(error, @"Failed to create temp directory: %@", self.tempDirectory);
    
    NSMutableArray *filesToCopy = [NSMutableArray arrayWithArray:testFiles];
    [filesToCopy addObjectsFromArray:unicodeFiles];
    
    for (NSString *file in filesToCopy) {
        NSURL *testFileURL = [self urlOfTestFile:file];
        BOOL testFileExists = [fm fileExistsAtPath:testFileURL.path];
        XCTAssertTrue(testFileExists, @"%@ not found", file);
        
        NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:file isDirectory:NO];
        
        NSError *error = nil;
        if (file.pathComponents.count > 1) {
            [fm createDirectoryAtPath:destinationURL.URLByDeletingLastPathComponent.path
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            XCTAssertNil(error, @"Failed to create directories for file %@", file);
        }
        
        [fm copyItemAtURL:testFileURL
                    toURL:destinationURL
                    error:&error];
        
        XCTAssertNil(error, @"Failed to copy temp file %@ from %@ to %@",
                     file, testFileURL, destinationURL);
        
        if ([testFiles containsObject:file]) {
            [self.testFileURLs setObject:destinationURL forKey:file];
        }
        else if ([unicodeFiles containsObject:file]) {
            [self.unicodeFileURLs setObject:destinationURL forKey:file];
        }
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *largeTextFiles = [NSMutableArray array];
        for (NSInteger i = 0; i < 20; i++) {
            [largeTextFiles addObject:[self randomTextFileOfLength:3000000]];
        }
        
        NSError *largeArchiveError = nil;
        
        NSURL *largeArchiveURLRandomName = [self archiveWithFiles:largeTextFiles];
        originalLargeArchiveURL = [largeArchiveURLRandomName.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive (Original).rar"];
        [fm moveItemAtURL:largeArchiveURLRandomName toURL:originalLargeArchiveURL error:&largeArchiveError];
        
        XCTAssertNil(largeArchiveError, @"Error renaming original large archive: %@", largeArchiveError);
    });
    
    NSString *largeArchiveName = @"Large Archive.rar";
    NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:largeArchiveName isDirectory:NO];
    [fm copyItemAtURL:originalLargeArchiveURL toURL:destinationURL error:&error];
    XCTAssertNil(error, @"Failed to copy the Large Archive");
    
    self.testFileURLs[largeArchiveName] = destinationURL;
    
    // Make a "corrupt" rar file
    NSURL *m4aFileURL = [self urlOfTestFile:@"Test File C.m4a"];
    self.corruptArchive = [self.tempDirectory URLByAppendingPathComponent:@"corrupt.rar"];
    [fm copyItemAtURL:m4aFileURL
                toURL:self.corruptArchive
                error:&error];
    
    XCTAssertNil(error, @"Failed to create corrupt archive (copy from %@ to %@)", m4aFileURL, self.corruptArchive);
}

- (void)tearDown
{
    NSString *largeArchiveDirectory = originalLargeArchiveURL.path.stringByDeletingLastPathComponent;
    BOOL tempDirContainsLargeArchive = [largeArchiveDirectory isEqualToString:self.tempDirectory.path];
    if (!self.testFailed && !tempDirContainsLargeArchive) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:self.tempDirectory error:&error];
        
        XCTAssertNil(error, @"Error deleting temp directory");
    }
    
    [super tearDown];
}

- (void) recordFailureWithDescription:(NSString *) description inFile:(NSString *) filename atLine:(NSUInteger) lineNumber expected:(BOOL) expected;
{
    self.testFailed = YES;
    [super recordFailureWithDescription:description inFile:filename atLine:lineNumber expected:expected];
}



#pragma mark - Helper Methods


- (NSURL *)urlOfTestFile:(NSString *)filename
{
    NSString *baseDirectory = @"Test Data";
    NSString *subPath = filename.stringByDeletingLastPathComponent;
    NSString *bundleSubdir = [baseDirectory stringByAppendingPathComponent:subPath];
    
    return [[NSBundle bundleForClass:[self class]] URLForResource:filename.lastPathComponent
                                                    withExtension:nil
                                                     subdirectory:bundleSubdir];
}

- (NSString *)randomDirectoryName
{
    NSString *globallyUnique = [[NSProcessInfo processInfo] globallyUniqueString];
    NSRange firstHyphen = [globallyUnique rangeOfString:@"-"];
    return [globallyUnique substringToIndex:firstHyphen.location];
}

- (NSString *)randomDirectoryWithPrefix:(NSString *)prefix
{
    return [NSString stringWithFormat:@"%@ %@", prefix, [self randomDirectoryName]];
}

- (NSInteger)numberOfOpenFileHandles {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/lsof";
    task.arguments = @[@"-P", @"-n", @"-p", [NSString stringWithFormat:@"%d", pid]];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *lsofOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    //    NSLog(@"LSOF:\n%@", lsofOutput);
    
    return [lsofOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]].count;
}

- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!\n";
    NSUInteger letterCount = letters.length;
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:numberOfCharacters];
    
    for (NSUInteger i = 0; i < numberOfCharacters; i++) {
        uint32_t charIndex = arc4random_uniform(letterCount);
        [randomString appendFormat:@"%C", [letters characterAtIndex:charIndex]];
    }
    
    NSURL *resultURL = [self.tempDirectory URLByAppendingPathComponent:
                        [NSString stringWithFormat:@"%@.txt", [[NSProcessInfo processInfo] globallyUniqueString]]];
    
    NSError *error = nil;
    [randomString writeToURL:resultURL atomically:YES encoding:NSUTF16StringEncoding error:&error];
    XCTAssertNil(error, @"Error opening file handle for text file creation: %@", error);
    
    return resultURL;
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs {
    NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    NSURL *rarExec = [[self.tempDirectory URLByAppendingPathComponent:@"bin"]
                      URLByAppendingPathComponent:@"rar"];
    NSURL *archiveURL = [[self.tempDirectory URLByAppendingPathComponent:uniqueString]
                         URLByAppendingPathExtension:@"rar"];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = rarExec.path;
    task.arguments = [@[@"a", @"-ep", archiveURL.path] arrayByAddingObjectsFromArray:[fileURLs valueForKeyPath:@"path"]];
    
    [task launch];
    [task waitUntilExit];
    
    if (task.terminationStatus != 0) {
        NSLog(@"Failed to create RAR archive");
        return nil;
    }
    
    return archiveURL;
}

- (NSUInteger)crcOfTestFile:(NSString *)filename {
    NSURL *fileURL = [self urlOfTestFile:filename];
    NSData *fileContents = [[NSFileManager defaultManager] contentsAtPath:[fileURL path]];
    return crc32(0, fileContents.bytes, fileContents.length);
}



@end
