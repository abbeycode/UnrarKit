//
//  Unrar4iOS.mm
//  Unrar4iOS
//
//  Created by Rogerio Pereira Araujo on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Unrar4iOS.h"

@interface Unrar4iOS(PrivateMethods)
-(BOOL)_unrarOpenFile:(NSString*)rarFile mode:(NSInteger)mode;
-(BOOL)_unrarOpenFile:(NSString*)rarFile password:(NSString*)password;
-(BOOL)_unrarCloseFile;
@end

@implementation Unrar4iOS

@synthesize filename;

int CALLBACK CallbackProc(UINT msg, long UserData, long P1, long P2) {
	UInt8 **buffer;
	
	switch(msg) {
			
		case UCM_CHANGEVOLUME:
			break;
		case UCM_PROCESSDATA:
			buffer = (UInt8 **) UserData;
			memcpy(*buffer, (UInt8 *)P1, P2);
			// advance the buffer ptr, original m_buffer ptr is untouched
			*buffer += P2;
			break;
		case UCM_NEEDPASSWORD:
			break;
	}
	return(0);
}

-(BOOL) unrarOpenFile:(NSString*)rarFile {
	self.filename = rarFile;
	return YES;
}

-(BOOL) _unrarOpenFile:(NSString*)rarFile mode:(NSInteger)mode{
	
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

-(BOOL) _unrarOpenFile:(NSString*)rarFile password:(NSString*)password {
	
	return NO;
}

-(NSArray *) unrarListFiles {
	int RHCode = 0, PFCode = 0;

	[self _unrarOpenFile:filename mode:RAR_OM_LIST];
	
	NSMutableArray *files = [NSMutableArray array];
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
		NSString *_filename = [NSString stringWithCString:header->FileName encoding:NSASCIIStringEncoding];
		[files addObject:_filename];
		
		if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
			[self _unrarCloseFile];
			return nil;
		}
	}

	[self _unrarCloseFile];
	return files;
}

-(BOOL) unrarFileTo:(NSString*)path overWrite:(BOOL)overwrite {
	
	return NO;
}

-(NSData *) extractStream:(NSString *)aFile {
	
	size_t length = 0;

	int RHCode = 0, PFCode = 0;
	
	[self _unrarOpenFile:filename mode:RAR_OM_EXTRACT];
	
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
		NSString *_filename = [NSString stringWithCString:header->FileName encoding:NSASCIIStringEncoding];
				
		if ([_filename isEqualToString:aFile]) {
			length = header->UnpSize;
			break;
		} 
		else {
			if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
				[self _unrarCloseFile];
				return nil;
			}
		}
	}
	
	if (length == 0) { // archived file not found
		[self _unrarCloseFile];
		return nil;
	}
	
	UInt8 *buffer = new UInt8[length];
	UInt8 *callBackBuffer = buffer;
	
	RARSetCallback(_rarFile, CallbackProc, (long) &callBackBuffer);
	
	PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);
	
	[self _unrarCloseFile];
	
	return [NSData dataWithBytes:buffer length:length];
}

-(BOOL) _unrarCloseFile {
	if (_rarFile)
		RARCloseArchive(_rarFile);
	
	delete flags;
	return YES;
}

-(BOOL) unrarCloseFile {
	return YES;
}


-(void) dealloc {
	[filename release];
	[super dealloc];
}

@end
