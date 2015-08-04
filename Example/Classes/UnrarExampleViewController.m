//
//  UnrarExampleViewController.m
//  UnrarExample
//
//

#import "UnrarExampleViewController.h"
#import <UnrarKit/UnrarKit.h>

@implementation UnrarExampleViewController

- (IBAction)decompress:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Test Archive (Password)" ofType:@"rar"];

    NSError *archiveError = nil;
	URKArchive *archive = [[URKArchive alloc] initWithPath:filePath error:&archiveError];
    
    if (!archive) {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Failed to create archive"
                                                                            message:@"Error creating the archive"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:controller animated:YES completion:nil];
        return;
    }
    
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


@end
