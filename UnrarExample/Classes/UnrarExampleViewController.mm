//
//  UnrarExampleViewController.m
//  UnrarExample
//
//  Created by Rogerio Pereira Araujo on 08/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UnrarExampleViewController.h"
#import <Unrar4IOS/RARExtractException.h>

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
	//NSString *filePath = [[NSBundle mainBundle] pathForResource:@"not_protected" ofType:@"cbr"]; 
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"protected" ofType:@"cbr"]; 

	Unrar4iOS *unrar = [[Unrar4iOS alloc] init];
	BOOL ok = [unrar unrarOpenFile:filePath];
	if (ok) {
		NSArray *files = [unrar unrarListFiles];
		for (NSString *filename in files) {
			NSLog(@"File: %@", filename);
		}
		
		// Extract a stream
        try {
            NSData *data = [unrar extractStream:[files objectAtIndex:0]];
            if (data != nil) {
                UIImage *image = [UIImage imageWithData:data];
                imageView.image = image;
            }
        }
        catch(RARExtractException *error) {
            
            if(error.status == RARArchiveProtected) {
                
                NSLog(@"Password protected archive!");
            }
        }
						
		[unrar unrarCloseFile];
	}
	else
		[unrar unrarCloseFile];
		
	[unrar release];
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
