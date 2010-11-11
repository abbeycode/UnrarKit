//
//  Unrar4iOS.mm
//  Unrar4iOS
//
//  Created by Rogerio Pereira Araujo on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Unrar4iOS.h"

@implementation Unrar4iOS

-(BOOL) UnrarOpenFile:(NSString*)rarFile mode:(NSInteger)mode{
	
	header = new RARHeaderDataEx;
	flags  = new RAROpenArchiveDataEx;
	
	const char *filenameData = (const char *) [rarFile UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->ArcNameW = NULL;
	flags->CmtBuf = NULL;
	flags->OpenMode = mode;
	
	_rarFile = RAROpenArchiveEx(flags);
	if (flags->OpenResult != 0) 
		return NO;
	
	header->CmtBuf = NULL;	
	return YES;
}

-(BOOL) UnrarOpenFile:(NSString*)rarFile password:(NSString*)password {
	
	return NO;
}

-(NSArray *) UnrarListFiles {
	int RHCode = 0, PFCode = 0;

	NSMutableArray *files = [NSMutableArray array];
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
		NSString *filename = [NSString stringWithCString:header->FileName];
		[files addObject:filename];
		
		if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) 
			return nil;
	}
	
	return files;
}

-(BOOL) UnrarFileTo:(NSString*)path overWrite:(BOOL)overwrite {
	
	return NO;
}

-(BOOL) UnrarCloseFile {
	if (_rarFile)
		RARCloseArchive(_rarFile);
	
	delete header;
	delete flags;
	return YES;
}

@end
