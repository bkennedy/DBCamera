//
//  RBVolumeButtons.h
//  VolumeSnap
//
//  Created by Randall Brown on 11/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^ButtonBlock)();

@interface RBVolumeButtons : NSObject
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0

{
   float launchVolume;
   BOOL hadToLowerVolume;
   BOOL hadToRaiseVolume;
   
   BOOL _isStealingVolumeButtons;
   BOOL _suspended;
   UIView *_volumeView;
}

@property (nonatomic, copy) ButtonBlock upBlock;
@property (nonatomic, copy) ButtonBlock downBlock;
@property (readonly) float launchVolume;
@property (nonatomic, assign) UIView *parentView;

-(void)startStealingVolumeButtonEvents;
-(void)stopStealingVolumeButtonEvents;
#endif
@end
