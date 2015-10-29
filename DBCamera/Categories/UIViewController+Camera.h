//
//  UIViewController+Camera.h
//  Tamarin
//
//  Created by BK on 11/17/14.
//
//

#import <UIKit/UIKit.h>

@interface UIViewController (Camera)
+ (void)rotatePinnedViews:(NSArray *)views forOrientation:(UIInterfaceOrientation)orientation;
    
+ (CGAffineTransform)pinnedViewTansformForOrientation:(UIInterfaceOrientation)orientation counter:(BOOL)counter;

@end
