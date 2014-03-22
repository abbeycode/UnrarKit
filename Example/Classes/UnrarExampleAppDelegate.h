//
//  UnrarExampleAppDelegate.h
//  UnrarExample
//
//  Created by Rogerio Pereira Araujo on 08/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UnrarExampleViewController;

@interface UnrarExampleAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    UnrarExampleViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UnrarExampleViewController *viewController;

@end

