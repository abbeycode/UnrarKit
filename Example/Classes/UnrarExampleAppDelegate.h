//
//  UnrarExampleAppDelegate.h
//  UnrarExample
//
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

