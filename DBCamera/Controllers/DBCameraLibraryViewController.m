//
//  DBCameraLibraryViewController.m
//  DBCamera
//
//  Created by iBo on 06/03/14.
//  Copyright (c) 2014 PSSD - Daniele Bogo. All rights reserved.
//

#import "DBCameraLibraryViewController.h"
#import "DBLibraryManager.h"
#import "DBCollectionViewCell.h"
#import "DBCollectionViewFlowLayout.h"
#import "DBCameraSegueViewController.h"
#import "DBCameraCollectionViewController.h"
#import "DBCameraMacros.h"
#import "DBCameraLoadingView.h"

#import "UIImage+Crop.h"
#import "UIImage+TintColor.h"
#import "UIImage+Asset.h"
#import "UIImage+Bundle.h"

#ifndef DBCameraLocalizedStrings
#define DBCameraLocalizedStrings(key) \
[[NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"DBCamera" ofType:@"bundle"]] localizedStringForKey:(key) value:@"" table:@"DBCamera"]
#endif

#define kItemIdentifier @"ItemIdentifier"
#define kContainers 3
#define kScrollViewTag 101

@interface DBCameraLibraryViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, DBCameraCollectionControllerDelegate> {
    NSMutableArray *_items;
    UILabel *_titleLabel, *_pageLabel;
    NSMutableDictionary *_containersMapping;
    UIPageViewController *_pageViewController;
    NSUInteger _vcIndex;
    NSUInteger _presentationIndex;
    BOOL _isEnumeratingGroups;
}

@property (nonatomic, weak) NSString *selectedItemID;
@property (nonatomic, strong) UIView *topContainerBar, *bottomContainerBar, *loading;
@end

@implementation DBCameraLibraryViewController
@synthesize cameraSegueConfigureBlock = _cameraSegueConfigureBlock;
@synthesize forceQuadCrop = _forceQuadCrop;
@synthesize useCameraSegue = _useCameraSegue;
@synthesize tintColor = _tintColor;
@synthesize selectedTintColor = _selectedTintColor;

- (id) init
{
    return [[DBCameraLibraryViewController alloc] initWithDelegate:nil];
}

- (id) initWithDelegate:(id<DBCameraContainerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _presentationIndex = 0;
        _containerDelegate = delegate;
        _containersMapping = [NSMutableDictionary dictionary];
        _items = [NSMutableArray array];
        _libraryMaxImageSize = 1900;
        [self setTintColor:[UIColor whiteColor]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:self.topContainerBar];
    [self.view addSubview:self.bottomContainerBar];
    
    _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                        options:@{ UIPageViewControllerOptionInterPageSpacingKey :@0 }];
    
    [_pageViewController setDelegate:self];
    [_pageViewController setDataSource:self];
    [self addChildViewController:_pageViewController];
    [self.view addSubview:_pageViewController.view];
    
    [_pageViewController didMoveToParentViewController:self];
    [_pageViewController.view setFrame:(CGRect){ 0, CGRectGetMaxY(_topContainerBar.frame), CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - ( CGRectGetHeight(_topContainerBar.frame) + CGRectGetHeight(_bottomContainerBar.frame) ) }];

    [self.view addSubview:self.loading];
    [self.view setGestureRecognizers:_pageViewController.gestureRecognizers];
    _titleLabel.text = @"ALL PHOTOS";

	[self loadLibraryGroups];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
#endif
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification
                                                  object:[UIApplication sharedApplication]];
}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) applicationDidBecomeActive:(NSNotification*)notifcation
{
    [self loadLibraryGroups];
}

- (void) applicationDidEnterBackground:(NSNotification*)notifcation
{
    [_pageViewController.view setAlpha:0];
}

- (void) loadLibraryGroups
{
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

    PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:allPhotosOptions];
    _items = [@[] mutableCopy];
    [result enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"%@", obj);
        [_items addObject:obj];
    }];
    [self loadPhotos:_items];
}

- (void)loadPhotos:(NSMutableArray*)items {
    [self.loading removeFromSuperview];
    
    if (items.count > 0) {
        DBCameraCollectionViewController *vc = [[DBCameraCollectionViewController alloc] initWithCollectionIdentifier:kItemIdentifier];
        [vc setItems:items];
        [vc setCollectionControllerDelegate:self];
        [self addChildViewController:vc];
        [self.view addSubview:vc.view];
        [vc didMoveToParentViewController:self];
        [vc.view setFrame:(CGRect){ 0, CGRectGetMaxY(_topContainerBar.frame), CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - ( CGRectGetHeight(_topContainerBar.frame) + CGRectGetHeight(_bottomContainerBar.frame) ) }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:DBCameraLocalizedStrings(@"general.error.title")
                                        message:DBCameraLocalizedStrings(@"pickerimage.nophoto")
                                       delegate:nil
                              cancelButtonTitle:@"Ok"
                              otherButtonTitles:nil, nil] show];
        });
    }
}


- (void) setNavigationTitleAtIndex:(NSUInteger)index
{
    [_titleLabel setText:[_items[index][@"groupTitle"] uppercaseString]];
    [_pageLabel setText:[NSString stringWithFormat:DBCameraLocalizedStrings(@"pagecontrol.text"), index + 1, _items.count ]];
}

- (NSInteger) indexForSelectedItem
{
    __weak typeof(self) blockSelf = self;
    __block NSInteger blockIndex = -1;

    [_items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( [blockSelf.selectedItemID isEqualToString:obj[@"propertyID"]] ) {
            *stop = YES;
            blockIndex = idx;
        }
    }];
    
    return blockIndex;
}

- (void) close
{
    if ( !self.containerDelegate ) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
        
    [UIView animateWithDuration:.3 animations:^{
        [self.view setAlpha:0];
        [self.view setTransform:CGAffineTransformMakeScale(.8, .8)];
    } completion:^(BOOL finished) {
        [self.containerDelegate backFromController:self];
    }];
}

- (void) setLibraryMaxImageSize:(NSUInteger)libraryMaxImageSize
{
    if ( libraryMaxImageSize > 0 )
        _libraryMaxImageSize = libraryMaxImageSize;
}

- (UIView *) loading
{
    if( !_loading ) {
        _loading = [[DBCameraLoadingView alloc] initWithFrame:(CGRect){ 0, 0, 100, 100 }];
        [_loading setCenter:self.view.center];
    }
    
    return _loading;
}

- (UIView *) topContainerBar
{
    if ( !_topContainerBar ) {
        _topContainerBar = [[UIView alloc] initWithFrame:(CGRect){ 0, 0, CGRectGetWidth(self.view.bounds), 65 }];
        [_topContainerBar setBackgroundColor:RGBColor(0x000000, 1)];
        
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [closeButton setBackgroundColor:[UIColor clearColor]];
        [closeButton setImage:[[UIImage imageInBundleNamed:@"close"] tintImageWithColor:self.tintColor] forState:UIControlStateNormal];
        [closeButton setFrame:(CGRect){ 10, 10, 45, 45 }];
        [closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
        [_topContainerBar addSubview:closeButton];
        
        _titleLabel = [[UILabel alloc] initWithFrame:(CGRect){ CGRectGetMaxX(closeButton.frame), 0, CGRectGetWidth(self.view.bounds) - (CGRectGetWidth(closeButton.bounds) * 2), CGRectGetHeight(_topContainerBar.bounds) }];
        [_titleLabel setBackgroundColor:[UIColor clearColor]];
        [_titleLabel setTextColor:self.tintColor];
        [_titleLabel setFont:[UIFont systemFontOfSize:12]];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
        [_topContainerBar addSubview:_titleLabel];
    }
    return _topContainerBar;
}

- (UIView *) bottomContainerBar
{
    if ( !_bottomContainerBar ) {
        _bottomContainerBar = [[UIView alloc] initWithFrame:(CGRect){ 0, CGRectGetHeight(self.view.bounds) - 30, CGRectGetWidth(self.view.bounds), 30 }];
        [_bottomContainerBar setBackgroundColor:RGBColor(0x000000, 1)];
        
        _pageLabel = [[UILabel alloc] initWithFrame:_bottomContainerBar.bounds ];
        [_pageLabel setBackgroundColor:[UIColor clearColor]];
        [_pageLabel setTextColor:self.tintColor];
        [_pageLabel setFont:[UIFont systemFontOfSize:12]];
        [_pageLabel setTextAlignment:NSTextAlignmentCenter];
        [_bottomContainerBar addSubview:_pageLabel];
    }
    
    return _bottomContainerBar;
}

#pragma mark - UIPageViewControllerDataSource Method

- (UIViewController *) pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    DBCameraCollectionViewController *vc = (DBCameraCollectionViewController *)viewController;
    
    _vcIndex = vc.currentIndex;
    
    if ( _vcIndex == 0 )
        return nil;
    
    DBCameraCollectionViewController *beforeVc = _containersMapping[@(_vcIndex - 1)];
    [beforeVc.collectionView reloadData];
    return beforeVc;
}

- (UIViewController *) pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    DBCameraCollectionViewController *vc = (DBCameraCollectionViewController *)viewController;
    _vcIndex = vc.currentIndex;
    
    if ( _vcIndex == (_items.count - 1) )
        return nil;
    
    DBCameraCollectionViewController *nextVc = _containersMapping[@(_vcIndex + 1)];
    [nextVc.collectionView reloadData];
    return nextVc;
}

#pragma mark - UIPageViewControllerDelegate

- (void) pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
    NSUInteger itemIndex = [(DBCameraCollectionViewController *)pendingViewControllers[0] currentIndex];
    [self setNavigationTitleAtIndex:itemIndex];
    [self setSelectedItemID:_items[itemIndex][@"propertyID"]];
}

#pragma mark - DBCameraCollectionControllerDelegate

- (void) collectionView:(UICollectionView *)collectionView itemURL:(NSURL *)URL
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view addSubview:self.loading];

        __weak typeof(self) weakSelf = self;
        [[[DBLibraryManager sharedInstance] defaultAssetsLibrary] assetForURL:URL resultBlock:^(ALAsset *asset) {
            ALAssetRepresentation *defaultRep = [asset defaultRepresentation];
            NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary:[defaultRep metadata]];
            metadata[@"DBCameraSource"] = @"Library";
            if ([defaultRep url]) {
                metadata[@"DBCameraAssetURL"] = [[defaultRep url] absoluteString];
            }

            UIImage *image = [UIImage imageForAsset:asset maxPixelSize:_libraryMaxImageSize];
//            UIImage *image = [self test:asset];
            
            [self extractEXIF: URL
                     complete:^(NSDictionary *exif, NSError *err){
                         NSDictionary *gpsInfo = [exif objectForKey:@"{GPS}"];
                         if (gpsInfo)
                             [metadata setObject:gpsInfo forKey:@"{GPS}"];
                         if ( !weakSelf.useCameraSegue ) {
                             if ( [weakSelf.delegate respondsToSelector:@selector(camera:didFinishWithImage:withMetadata:)] )
                                 [weakSelf.delegate camera:self didFinishWithImage:image withMetadata:metadata];
                         } else {
                             DBCameraSegueViewController *segue = [[DBCameraSegueViewController alloc] initWithImage:image thumb:[UIImage imageWithCGImage:[asset aspectRatioThumbnail]]];
                             [segue setTintColor:self.tintColor];
                             [segue setSelectedTintColor:self.selectedTintColor];
                             [segue setForceQuadCrop:_forceQuadCrop];
                             [segue enableGestures:YES];
                             [segue setCapturedImageMetadata:metadata];
                             [segue setDelegate:weakSelf.delegate];
                             [segue setCameraSegueConfigureBlock:self.cameraSegueConfigureBlock];
                             
                             [weakSelf.navigationController pushViewController:segue animated:YES];
                         }
                     }];


            
            [weakSelf.loading removeFromSuperview];
        } failureBlock:nil];
    });
}

- (void) collectionView:(UICollectionView *)collectionView asset:(PHAsset *)asset
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view addSubview:self.loading];
        
        __weak typeof(self) weakSelf = self;
        PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc]init];
        editOptions.networkAccessAllowed = YES;
        
        [asset requestContentEditingInputWithOptions:editOptions completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
            CIImage *ciImage = [CIImage imageWithContentsOfURL:contentEditingInput.fullSizeImageURL];
            UIImage *image = contentEditingInput.displaySizeImage;
            NSMutableDictionary *metadata = [ciImage.properties mutableCopy];

            if ( !weakSelf.useCameraSegue ) {
                if ( [weakSelf.delegate respondsToSelector:@selector(camera:didFinishWithImage:withMetadata:)] )
                    [weakSelf.delegate camera:self didFinishWithImage:image withMetadata:metadata];
            } else {
                DBCameraSegueViewController *segue = [[DBCameraSegueViewController alloc] initWithImage:image thumb:image];
                [segue setTintColor:self.tintColor];
                [segue setSelectedTintColor:self.selectedTintColor];
                [segue setForceQuadCrop:_forceQuadCrop];
                [segue enableGestures:YES];
                [segue setCapturedImageMetadata:metadata];
                [segue setDelegate:weakSelf.delegate];
                [segue setCameraSegueConfigureBlock:self.cameraSegueConfigureBlock];
                
                [weakSelf.navigationController pushViewController:segue animated:YES];
            }
            [weakSelf.loading removeFromSuperview];
        }];

        
    });
}


-(void)extractEXIF:(NSURL*)imageUrl complete:(ExtractEXIFComplete)complete{
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *asset)
    {
        //if (asset.originalAsset) asset = asset.originalAsset;
        NSDictionary *metadata = (NSDictionary*)[[asset defaultRepresentation] metadata];
        complete(metadata, nil);
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        complete(nil, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL:imageUrl
                   resultBlock:resultblock
                  failureBlock:failureblock];
}

//- (UIImage *) test:(ALAsset *)asset
//{
//    ALAssetRepresentation *representation = asset.defaultRepresentation;
//    CGImageRef fullResolutionImage = CGImageRetain(representation.fullResolutionImage);
//    // AdjustmentXMP constains the Extensible Metadata Platform XML of the photo
//    // This XML describe the transformation done to the image.
//    // http://en.wikipedia.org/wiki/Extensible_Metadata_Platform
//    // Have in mind that the key is not exactly documented.
//    NSString *adjustmentXMP = [representation.metadata objectForKey:@"AdjustmentXMP"];
//    
//    NSData *adjustmentXMPData = [adjustmentXMP dataUsingEncoding:NSUTF8StringEncoding];
//    NSError *__autoreleasing error = nil;
//    CGRect extend = CGRectZero;
//    extend.size = representation.dimensions;
//    NSArray *filters = [CIFilter filterArrayFromSerializedXMP:adjustmentXMPData inputImageExtent:extend error:&error];
//    if (filters)
//    {
//        CIImage *image = [CIImage imageWithCGImage:fullResolutionImage];
//        CIContext *context = [CIContext contextWithOptions:nil];
//        for (CIFilter *filter in filters)
//        {
//            [filter setValue:image forKey:kCIInputImageKey];
//            image = [filter outputImage];
//        }
//        
//        fullResolutionImage = [context createCGImage:image fromRect:image.extent];
//    }
//    
//    UIImage *toReturn = [UIImage imageWithCGImage:fullResolutionImage];
//    CGImageRelease(fullResolutionImage);
//    return toReturn;
//}

@end