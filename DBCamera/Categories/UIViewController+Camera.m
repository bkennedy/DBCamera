//
//  UIViewController+Camera.m
//  Tamarin
//
//  Created by BK on 11/17/14.
//
//

#import "UIViewController+Camera.h"

@implementation UIViewController (Camera)
+ (void)rotatePinnedViews:(NSArray *)views forOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIDeviceOrientationFaceUp ||
        orientation == UIDeviceOrientationFaceDown)
            return;
    
    const CGAffineTransform t = [UIViewController pinnedViewTansformForOrientation:orientation counter:NO];
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.transform = t;
        view.tag = orientation;
    }];
}

+ (CGAffineTransform)pinnedViewTansformForOrientation:(UIInterfaceOrientation)orientation counter:(BOOL)counter {
    CGAffineTransform t;
    switch ( orientation ) {
        case UIInterfaceOrientationPortrait:
            t = CGAffineTransformIdentity;
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            t = CGAffineTransformMakeRotation(M_PI);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            t = CGAffineTransformMakeRotation(counter ? M_PI_2 : -M_PI_2);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            t = CGAffineTransformMakeRotation(counter ?  -M_PI_2:M_PI_2);
            break;
        default:
            t = CGAffineTransformIdentity;
            break;
    }
    
    return t;
}
@end
