//
//  UnrarExampleViewController.h
//  UnrarExample
//
//

#import <UIKit/UIKit.h>

@interface UnrarExampleViewController : UIViewController {
    
	IBOutlet UIButton		*decompressButton;
	IBOutlet UIImageView	*imageView;
}

- (IBAction)decompress:(id)sender;

@end

