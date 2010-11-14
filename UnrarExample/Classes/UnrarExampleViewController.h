//
//  UnrarExampleViewController.h
//  UnrarExample
//
//  Created by Rogerio Pereira Araujo on 08/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Unrar4iOS/Unrar4iOS.h>

@interface UnrarExampleViewController : UIViewController {
    
	IBOutlet UIButton		*decompressButton;
	IBOutlet UIImageView	*imageView;
}

- (IBAction)decompress:(id)sender;

@end

