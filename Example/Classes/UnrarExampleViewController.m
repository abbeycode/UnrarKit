//
//  UnrarExampleViewController.m
//  UnrarExample
//
//

#import "UnrarExampleViewController.h"
#import <UnrarKit/UnrarKit.h>

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
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Test Archive (Password)" ofType:@"rar"];

	URKArchive *archive = [URKArchive rarArchiveAtPath:filePath];
    NSError *error = nil;
    NSArray *filenames = [archive listFilenames:&error];
    
	if (error) {
        NSLog(@"Error reading archive: %@", error);
        return;
    }
    
    for (NSString *filename in filenames) {
        NSLog(@"File: %@", filename);
    }
    
    // Extract a file into memory
    NSData *data = [archive extractDataFromFile:filenames[0] progress:nil error:&error];

    if (error) {
        if (error.code == ERAR_MISSING_PASSWORD) {
            NSLog(@"Password protected archive!");
        }
    }
    
    if (data != nil) {
        UIImage *image = [UIImage imageWithData:data];
        imageView.image = image;
    }
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


- (void)dealloc {
    [super dealloc];
}

@end
