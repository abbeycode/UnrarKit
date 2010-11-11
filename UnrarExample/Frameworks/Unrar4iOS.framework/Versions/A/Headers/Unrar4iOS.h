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

-(BOOL) UnrarOpenFile:(NSString*) rarFile mode:(NSInteger)mode;
-(BOOL) UnrarOpenFile:(NSString*) rarFile password:(NSString*) password;
-(NSArray *) UnrarListFiles;
-(BOOL) UnrarFileTo:(NSString*) path overWrite:(BOOL) overwrite;
-(BOOL) UnrarCloseFile;

@end
