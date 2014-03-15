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

	HANDLE	 _rarFile;
	struct	 RARHeaderDataEx *header;
	struct	 RAROpenArchiveDataEx *flags;
}

@property(nonatomic, retain) NSString* filename;
@property(nonatomic, retain) NSString* password;

-(BOOL) unrarOpenFile:(NSString*) rarFile;
-(BOOL) unrarOpenFile:(NSString*) rarFile withPassword:(NSString*) aPassword;
-(NSArray *) unrarListFiles:(NSError **)error;
-(BOOL) unrarFileTo:(NSString*) path overWrite:(BOOL) overwrite error:(NSError **)error;
-(NSData *) extractStream:(NSString *)aFile error:(NSError **)error;
-(BOOL) unrarCloseFile;

@end
