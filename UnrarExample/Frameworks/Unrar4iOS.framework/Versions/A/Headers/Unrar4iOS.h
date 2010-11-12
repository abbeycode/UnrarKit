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

@interface Unrar4iOS : NSObject {

	HANDLE _rarFile;
	struct RARHeaderDataEx *header;
	struct RAROpenArchiveDataEx *flags;
	
}

-(BOOL) unrarOpenFile:(NSString*) rarFile mode:(NSInteger) mode;
-(BOOL) unrarOpenFile:(NSString*) rarFile password:(NSString*) password;
-(NSArray *) unrarListFiles;
-(BOOL) unrarFileTo:(NSString*) path overWrite:(BOOL) overwrite;
-(BOOL) unrarCloseFile;

@end
