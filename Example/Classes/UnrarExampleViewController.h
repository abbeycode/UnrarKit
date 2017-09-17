//
//  UnrarExampleViewController.h
//  UnrarExample
//
//

#import <UIKit/UIKit.h>

@interface UnrarExampleViewController : UIViewController


@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UITextView *fileListTextView;


- (IBAction)listFiles:(id)sender;

@end

