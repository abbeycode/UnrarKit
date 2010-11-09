//
//  UnrarExampleViewController.m
//  UnrarExample
//
//  Created by Rogerio Pereira Araujo on 08/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UnrarExampleViewController.h"
#import "dll.hpp"

@implementation UnrarExampleViewController

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction)decompress:(id)sender {
	HANDLE rarFile;
	int RHCode = 0, PFCode = 0;
	struct RARHeaderDataEx header;
	struct RAROpenArchiveDataEx flags;
	
	rarFile = [self openRar:&flags header:&header mode:RAR_OM_LIST];
	
	while ((RHCode = RARReadHeaderEx(rarFile, &header)) == 0) {
		NSString *filename = [NSString stringWithCString:header.FileName];
		NSLog(@"File: %@", filename);
		
		if ((PFCode = RARProcessFile(rarFile, RAR_SKIP, NULL, NULL)) != 0) {
			[self closeRar:rarFile flags:&flags];
		}		
	}
	
	[self closeRar:rarFile flags:&flags];    
}

- (HANDLE) openRar:(RAROpenArchiveDataEx *)flags header:(RARHeaderDataEx *)aHeader mode:(UInt8) aMode {
	
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Venom - Licença para Matar #01" ofType:@"cbr"]; 
	
	HANDLE rarFile;
	
	memset(flags, 0, sizeof(*flags));
	const char *filenameData = (const char *) [filePath UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->CmtBuf = NULL;
	flags->OpenMode = aMode;
	
	rarFile = RAROpenArchiveEx(flags);
	if (flags->OpenResult != 0) {
		[self closeRar:rarFile flags:flags];
	}
	
	aHeader->CmtBuf = NULL;
	
	return rarFile;																									   
}

- (HANDLE) closeRar:(HANDLE)rarFile flags:(RAROpenArchiveDataEx *)aFlags {
	if (rarFile)
		RARCloseArchive(rarFile);
	
	delete[] aFlags->ArcName;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

@end
