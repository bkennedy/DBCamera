//
//  DBCameraViewController.m
//  DBCamera
//
//  Created by iBo on 31/01/14.
//  Copyright (c) 2014 PSSD - Daniele Bogo. All rights reserved.
//

#import "DBCameraViewController.h"
#import "DBCameraManager.h"
#import "DBCameraView.h"
#import "DBCameraGridView.h"
#import "DBCameraDelegate.h"
#import "DBCameraSegueViewController.h"
#import "DBCameraLibraryViewController.h"
#import "DBLibraryManager.h"
#import "DBMotionManager.h"

#import "UIImage+Crop.h"
#import "UIViewController+Camera.h"
#import "DBCameraMacros.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>


#ifndef DBCameraLocalizedStrings
#define DBCameraLocalizedStrings(key) \
[[NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"DBCamera" ofType:@"bundle"]] localizedStringForKey:(key) value:@"" table:@"DBCamera"]
#endif

@interface DBCameraViewController () <DBCameraManagerDelegate, DBCameraViewDelegate> {
    UIDeviceOrientation _deviceOrientation;
    BOOL wasStatusBarHidden;
    BOOL wasWantsFullScreenLayout;
}

@property (nonatomic, strong) id customCamera;
@end

@implementation DBCameraViewController
@synthesize cameraGridView = _cameraGridView;
@synthesize forceQuadCrop = _forceQuadCrop;
@synthesize tintColor = _tintColor;
@synthesize selectedTintColor = _selectedTintColor;
@synthesize cameraSegueConfigureBlock = _cameraSegueConfigureBlock;
@synthesize cameraManager = _cameraManager;

#pragma mark - Life cycle

+ (instancetype) initWithDelegate:(id<DBCameraViewControllerDelegate>)delegate
{
    return [[self alloc] initWithDelegate:delegate cameraView:nil];
}

+ (instancetype) init
{
    return [[self alloc] initWithDelegate:nil cameraView:nil];
}

- (instancetype) initWithDelegate:(id<DBCameraViewControllerDelegate>)delegate cameraView:(id)camera
{
    self = [super init];

    if ( self ) {
        _processingPhoto = NO;
        _deviceOrientation = [[UIDevice currentDevice] orientation];
        if ( delegate )
            _delegate = delegate;

        if ( camera )
            [self setCustomCamera:camera];

        [self setUseCameraSegue:YES];

        [self setTintColor:[UIColor whiteColor]];
        [self setSelectedTintColor:[UIColor cyanColor]];
    }

    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    AudioSessionSetActive(YES);

    [self.view setBackgroundColor:[UIColor blackColor]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];


    NSError *error;
    if ( [self.cameraManager setupSessionWithPreset:AVCaptureSessionPresetPhoto error:&error] ) {
        if ( self.customCamera ) {
            if ( [self.customCamera respondsToSelector:@selector(previewLayer)] ) {
                [(AVCaptureVideoPreviewLayer *)[self.customCamera valueForKey:@"previewLayer"] setSession:self.cameraManager.captureSession];

                if ( [self.customCamera respondsToSelector:@selector(delegate)] )
                    [self.customCamera setValue:self forKey:@"delegate"];
            }

            [self.view addSubview:self.customCamera];
        } else
            [self.view addSubview:self.cameraView];
    }
    
    _volume = AVAudioSession.sharedInstance.outputVolume;


    _volumeView = [[MPVolumeView alloc] initWithFrame: CGRectZero];

    [self.view addSubview: _volumeView];
    [self.view sendSubviewToBack:_volumeView];

    id camera =_customCamera ?: _cameraView;
    [((DBCameraView *)camera).previewView insertSubview:self.cameraGridView atIndex:1];
    
    if ( [camera respondsToSelector:@selector(cameraButton)] ) {
        [(DBCameraView *)camera cameraButton].enabled = [self.cameraManager hasMultipleCameras];
        [self.cameraManager hasMultipleCameras];
    }
    
    self.pinnedViews = [NSMutableArray array];
    [self.pinnedViews addObject:self.cameraView.triggerButton];
    [self.pinnedViews addObject:self.cameraView.cameraButton];
    [self.pinnedViews addObject:self.cameraView.flashButton];
    [self.pinnedViews addObject:self.cameraView.gridButton];
    [self.pinnedViews addObject:self.cameraView.photoLibraryButton];

}

-(void) volumeChanged:(NSNotification*)notification {
    
    NSPredicate *sliders = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[UISlider class]];
    }];
    
    
    UISlider *slider = [self.volumeView.subviews filteredArrayUsingPredicate:sliders].firstObject;

    NSDictionary *userInfo = notification.userInfo;
    NSString *changeReason = userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
    if ([changeReason isEqualToString:@"ExplicitVolumeChange"]) {
        [slider setValue:self.volume animated: NO];

        if (!self.takenPhoto) {
            self.takenPhoto = YES;
            [self.cameraView triggerAction:self.cameraView.triggerButton];
        }
    }
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.cameraManager performSelector:@selector(startRunning) withObject:nil afterDelay:0.0];
    self.takenPhoto = NO;
    __weak typeof(self) weakSelf = self;
    [[DBMotionManager sharedManager] setMotionRotationHandler:^(UIDeviceOrientation orientation){
        [weakSelf rotationChanged:orientation];
    }];
    [[DBMotionManager sharedManager] startMotionHandler];
    
//    [self.cameraView setupVolumeButtons];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self initializeMotionManager];

    if ( !self.customCamera )
        [self checkForLibraryImage];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
//    [self.cameraView removeVolumeButtons];
    [self.motionManager stopAccelerometerUpdates];
    [self.cameraManager performSelector:@selector(stopRunning) withObject:nil afterDelay:0.0];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _cameraManager = nil;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void) checkForLibraryImage
{
    if ( !self.cameraView.photoLibraryButton.isHidden && [self.parentViewController.class isSubclassOfClass:NSClassFromString(@"DBCameraContainerViewController")] ) {
        if ( [ALAssetsLibrary authorizationStatus] !=  ALAuthorizationStatusDenied ) {
            __weak DBCameraView *weakCamera = self.cameraView;
            [[DBLibraryManager sharedInstance] loadLastItemWithBlock:^(BOOL success, UIImage *image) {
                [weakCamera.photoLibraryButton setBackgroundImage:image forState:UIControlStateNormal];
            }];
        }
    } else
        [self.cameraView.photoLibraryButton setHidden:YES];
}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

- (void) dismissCamera
{
    if ( _delegate && [_delegate respondsToSelector:@selector(dismissCamera:)] )
        [_delegate dismissCamera:self];
}

- (DBCameraView *) cameraView
{
    if ( !_cameraView ) {
        _cameraView = [DBCameraView initWithCaptureSession:self.cameraManager.captureSession];
        [_cameraView setDelegate:self];
        [_cameraView setTintColor:self.tintColor];
        [_cameraView setSelectedTintColor:self.selectedTintColor];
        [_cameraView defaultInterface];
    }

    return _cameraView;
}

- (DBCameraManager *) cameraManager
{
    if ( !_cameraManager ) {
        _cameraManager = [[DBCameraManager alloc] init];
        [_cameraManager setDelegate:self];
    }

    return _cameraManager;
}

- (DBCameraGridView *) cameraGridView
{
    if ( !_cameraGridView ) {
        DBCameraView *camera =_customCamera ?: _cameraView;
        _cameraGridView = [[DBCameraGridView alloc] initWithFrame:camera.previewView.frame];
        [_cameraGridView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_cameraGridView setNumberOfColumns:2];
        [_cameraGridView setNumberOfRows:2];
        [_cameraGridView setAlpha:0];
    }

    return _cameraGridView;
}

- (void) setCameraGridView:(DBCameraGridView *)cameraGridView
{
    _cameraGridView = cameraGridView;
    __block DBCameraGridView *blockGridView = cameraGridView;
    __weak DBCameraView *camera =_customCamera ?: _cameraView;
    [camera.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( [obj isKindOfClass:[DBCameraGridView class]] ) {
            [obj removeFromSuperview];
            [camera insertSubview:blockGridView atIndex:1];
            blockGridView = nil;
            *stop = YES;
        }
    }];
}

- (void) rotationChanged:(UIDeviceOrientation) orientation
{
    if ( orientation != UIDeviceOrientationUnknown ||
         orientation != UIDeviceOrientationFaceUp ||
         orientation != UIDeviceOrientationFaceDown ) {
        _deviceOrientation = orientation;
        self.cameraView.deviceOrientation = _deviceOrientation;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    DBCameraView *camera = _customCamera ?: _cameraView;
    camera.frame = CGRectMake(0, 0, size.width, size.height);
    camera.previewLayer.frame = CGRectMake(0, 0, size.width, size.height);
}

+ (AVCaptureVideoOrientation)interfaceOrientationToVideoOrientation:(UIInterfaceOrientation)orientation {
    return AVCaptureVideoOrientationPortrait;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
    DBCameraView *camera = _customCamera ?: _cameraView;
    if (camera.previewLayer.connection.supportsVideoOrientation
        && camera.previewLayer.connection.videoOrientation != videoOrientation) {
        camera.previewLayer.connection.videoOrientation = videoOrientation;
    }
}

#pragma mark - CameraManagerDelagate

- (void) closeCamera
{
    [self dismissCamera];
}

- (void) switchCamera
{
    if ( [self.cameraManager hasMultipleCameras] )
        [self.cameraManager cameraToggle];
}

- (void) cameraView:(UIView *)camera showGridView:(BOOL)show {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.cameraGridView.alpha = (show ? 1.0 : 0.0);
    } completion:NULL];
}

- (void) triggerFlashForMode:(AVCaptureFlashMode)flashMode
{
    if ( [self.cameraManager hasFlash] )
        [self.cameraManager setFlashMode:flashMode];
}

- (BOOL) hasFlash {
    return [self.cameraManager hasFlash];
}

- (void) captureImageDidFinish:(UIImage *)image withMetadata:(NSDictionary *)metadata
{
    _processingPhoto = NO;

    NSMutableDictionary *finalMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
    finalMetadata[@"DBCameraSource"] = @"Camera";

    if ( !self.useCameraSegue ) {
        if ( [_delegate respondsToSelector:@selector(camera:didFinishWithImage:withMetadata:)] )
            [_delegate camera:self didFinishWithImage:image withMetadata:finalMetadata];
    } else {
        CGFloat newW = 256.0;
        CGFloat newH = 340.0;

        if ( image.size.width > image.size.height ) {
            newW = 340.0;
            newH = ( newW * image.size.height ) / image.size.width;
        }

        DBCameraSegueViewController *segue = [[DBCameraSegueViewController alloc] initWithImage:image thumb:[UIImage returnImage:image withSize:(CGSize){ newW, newH }]];
        [segue setTintColor:self.tintColor];
        [segue setSelectedTintColor:self.selectedTintColor];
        [segue setForceQuadCrop:_forceQuadCrop];
        [segue enableGestures:YES];
        [segue setDelegate:self.delegate];
        [segue setCapturedImageMetadata:finalMetadata];
        [segue setCameraSegueConfigureBlock:self.cameraSegueConfigureBlock];

        [self.navigationController pushViewController:segue animated:YES];
    }
}

- (void) captureImageFailedWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    });
}

- (void) captureSessionDidStartRunning
{
    id camera = self.customCamera ?: _cameraView;
    CGRect bounds = [(UIView *)camera bounds];
    CGPoint screenCenter = (CGPoint){ CGRectGetMidX(bounds), CGRectGetMidY(bounds) };
    if ([camera respondsToSelector:@selector(drawFocusBoxAtPointOfInterest:andRemove:)] )
        [camera drawFocusBoxAtPointOfInterest:screenCenter andRemove:NO];
    if ( [camera respondsToSelector:@selector(drawExposeBoxAtPointOfInterest:andRemove:)] )
        [camera drawExposeBoxAtPointOfInterest:screenCenter andRemove:NO];
}

- (void) openLibrary
{
    if ( [ALAssetsLibrary authorizationStatus] !=  ALAuthorizationStatusDenied ) {
        [UIView animateWithDuration:.3 animations:^{
            [self.view setAlpha:0];
            [self.view setTransform:CGAffineTransformMakeScale(.8, .8)];
        } completion:^(BOOL finished) {
            DBCameraLibraryViewController *library = [[DBCameraLibraryViewController alloc] initWithDelegate:self.containerDelegate];
            [library setTintColor:self.tintColor];
            [library setSelectedTintColor:self.selectedTintColor];
            [library setForceQuadCrop:_forceQuadCrop];
            [library setDelegate:self.delegate];
            [library setUseCameraSegue:self.useCameraSegue];
            [library setCameraSegueConfigureBlock:self.cameraSegueConfigureBlock];
            [library setLibraryMaxImageSize:self.libraryMaxImageSize];
            [self.containerDelegate switchFromController:self toController:library];
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:DBCameraLocalizedStrings(@"general.error.title") message:DBCameraLocalizedStrings(@"pickerimage.nopolicy") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        });
    }
}

#pragma mark - CameraViewDelegate

- (void) cameraViewStartRecording
{
    if ( _processingPhoto )
        return;

    _processingPhoto = YES;

    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

        if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
            [[[UIAlertView alloc] initWithTitle:DBCameraLocalizedStrings(@"general.error.title")
                                        message:DBCameraLocalizedStrings(@"cameraimage.nopolicy")
                                       delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil, nil] show];

            return;
        }
        else if (status == AVAuthorizationStatusNotDetermined) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:nil];

            return;
        }
    }

    [self.cameraManager captureImageForDeviceOrientation:self.pinnedViews.count > 0 ? [(UIView*)self.pinnedViews[0] tag] : _deviceOrientation];// _deviceOrientation];
}

- (void) cameraView:(UIView *)camera focusAtPoint:(CGPoint)point
{
    if ( self.cameraManager.videoInput.device.isFocusPointOfInterestSupported ) {
        [self.cameraManager focusAtPoint:[self.cameraManager convertToPointOfInterestFrom:[[(DBCameraView *)camera previewLayer] frame]
                                                                              coordinates:point
                                                                                    layer:[(DBCameraView *)camera previewLayer]]];
    }
}

- (BOOL) cameraViewHasFocus
{
    return self.cameraManager.hasFocus;
}

- (void) cameraView:(UIView *)camera exposeAtPoint:(CGPoint)point
{
    if ( self.cameraManager.videoInput.device.isExposurePointOfInterestSupported ) {
        [self.cameraManager exposureAtPoint:[self.cameraManager convertToPointOfInterestFrom:[[(DBCameraView *)camera previewLayer] frame]
                                                                                 coordinates:point
                                                                                       layer:[(DBCameraView *)camera previewLayer]]];
    }
}

- (CGFloat) cameraMaxScale
{
    return [self.cameraManager cameraMaxScale];
}

- (void) cameraCaptureScale:(CGFloat)scaleNum
{
    [self.cameraManager setCameraMaxScale:scaleNum];
}

#pragma mark - UIApplicationDidEnterBackgroundNotification

- (void) applicationDidEnterBackground:(NSNotification *)notification
{
    id modalViewController = self.presentingViewController;
    if ( modalViewController )
        [self dismissCamera];
}

#pragma mark - Button Rotation
- (void)initializeMotionManager{
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.accelerometerUpdateInterval = .2;
    _motionManager.gyroUpdateInterval = .2;
    
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
                                                 if (!error) {
                                                     [self outputAccelertionData:accelerometerData.acceleration];
                                                 }
                                                 else{
                                                     NSLog(@"%@", error);
                                                 }
                                             }];
}

- (void)outputAccelertionData:(CMAcceleration)acceleration{
    UIInterfaceOrientation orientationNew;
    
    if (acceleration.x >= 0.75) {
        orientationNew = UIInterfaceOrientationLandscapeLeft;
    }
    else if (acceleration.x <= -0.75) {
        orientationNew = UIInterfaceOrientationLandscapeRight;
    }
    else if (acceleration.y <= -0.75) {
        orientationNew = UIInterfaceOrientationPortrait;
    }
    else if (acceleration.y >= 0.75) {
        orientationNew = UIInterfaceOrientationPortraitUpsideDown;
    }
    else {
        // Consider same as last time
        return;
    }
    
    if (orientationNew == self.orientationLast)
        return;
    
    self.orientationLast = orientationNew;
    [self orientationChanged:orientationNew];
}

-(void)orientationChanged:(UIInterfaceOrientation)toInterfaceOrientation {
    [UIViewController rotatePinnedViews:self.pinnedViews forOrientation:toInterfaceOrientation];
}

@end
