//
//  Unrar4iOS.h
//  Unrar4iOS
//
//  Created by Rogerio Pereira Araujo on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "raros.hpp"
#import "dll.hpp"

#define ERAR_ARCHIVE_NOT_FOUND  101

extern NSString *URRErrorDomain;

@interface Unrar4iOS : NSObject {

	HANDLE _rarFile;
	struct RARHeaderDataEx *header;
	struct RAROpenArchiveDataEx *flags;
}

@property(nonatomic, retain) NSString *filename;
@property(nonatomic, retain) NSString *password;

+ (Unrar4iOS *)unrarFileAtPath:(NSString *)filePath;
+ (Unrar4iOS *)unrarFileAtURL:(NSURL *)fileURL;
+ (Unrar4iOS *)unrarFileAtPath:(NSString *)filePath password:(NSString *)password;
+ (Unrar4iOS *)unrarFileAtURL:(NSURL *)fileURL password:(NSString *)password;

- (void)openFile:(NSString *)filePath;
- (void)openFile:(NSString *)filePath password:(NSString*)password;

- (NSArray *)listFiles:(NSError **)error;
- (BOOL)extractFilesTo:(NSString *)filePath overWrite:(BOOL)overwrite error:(NSError **)error;
- (NSData *)extractDataFromFile:(NSString *)filePath error:(NSError **)error;

- (BOOL)closeFile;

@end
