//
//  UnrarExampleViewController.m
//  UnrarExample
//
//

#import "UnrarExampleViewController.h"
@import UnrarKit;

@implementation UnrarExampleViewController

- (IBAction)listFiles:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Test Archive (Password)" ofType:@"rar"];

    NSError *archiveError = nil;
    URKArchive *archive = [[URKArchive alloc] initWithPath:filePath error:&archiveError];
    archive.password = self.passwordField.text;
    
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
    
	if (!filenames) {
        self.fileListTextView.text = error.localizedDescription;
        return;
    }
    
    NSMutableString *fileList = [NSMutableString string];
    
    for (NSString *filename in filenames) {
        [fileList appendFormat:@"• %@\n", filename];
    }
    
    self.fileListTextView.text = fileList;
}


@end
