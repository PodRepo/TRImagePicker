//
//  UzysAssetsPickerController.m
//  UzysAssetsPickerController
//
//  Created by Uzysjung on 2014. 2. 12..
//  Copyright (c) 2014년 Uzys. All rights reserved.
//
#import "UzysAssetsPickerController.h"
#import "UzysAssetsViewCell.h"
#import "UzysGroupPickerView.h"
#import "UzysTakePhotoCell.h"
#import "TGCameraNavigationController.h"
#import "TRCropViewController.h"
#import "UzysTitleView.h"
#import <ImageIO/ImageIO.h>

@interface UzysAssetsPickerController ()<UICollectionViewDataSource,UICollectionViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,TGCameraDelegate,TRCropViewControllerDelegate>
//View

@property (nonatomic, strong) UIView *noAssetView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UzysGroupPickerView *groupPicker;

@property (nonatomic, strong) ALAssetsGroup *assetsGroup; // currentGroup
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;

@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, assign) NSInteger numberOfPhotos; // 原有数量
@property (nonatomic, assign) NSInteger numberOfVideos;
@property (nonatomic, assign) NSInteger maximumNumberOfSelection;
/// 0 Media,2 video,1 photo
@property (nonatomic, assign) NSInteger curAssetFilterType;

@property (nonatomic, strong) NSMutableArray *orderedSelectedItem;

@property (nonatomic, strong) UzysTitleView *mTitleView;

@end

@implementation UzysAssetsPickerController

@synthesize location;

#pragma mark - ALAssetsLibrary

+ (ALAssetsLibrary *)defaultAssetsLibrary
{
    static ALAssetsLibrary *library = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    return library;
}

- (id)init
{
//    self = [super initWithNibName:@"UzysAssetsPickerController" bundle:nil];//[NSBundle bundleForClass:[UzysAssetsPickerController class]]
    if(self)
    {
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(assetsLibraryUpdated:) name:ALAssetsLibraryChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:ALAssetsLibraryChangedNotification object:nil];
    self.assetsLibrary = nil;
    self.assetsGroup = nil;
    self.assets = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self initVariable];
    
    __weak typeof(self) weakSelf = self;
    [self setupGroup:^{
        [weakSelf.groupPicker.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    } withSetupAsset:YES];
    [self initTitleView];
    [self setupCollectionView]; // 图片cell
    [self setupGroupPickerview]; // 文件夹选择
    [self initNoAssetView];
    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBarHidden = NO;
    
    //    UIColor *c = [UIColor colorWithRed:0xf8/255.0 green:0xf8/255.0 blue:0xf8/255.0 alpha:1.0];
    //    [self.navigationController.navigationBar lt_setBackgroundColor:c];
    
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    //
    UIFont *font = [UIFont boldSystemFontOfSize:19.f];
    NSDictionary *textAttributes = @{
                                     NSFontAttributeName : font,
                                     NSForegroundColorAttributeName : [UIColor blackColor]
                                     };
    [self.navigationController.navigationBar setTitleTextAttributes:textAttributes];
}

-(void)initTitleView
{
    UzysAppearanceConfig *appearanceConfig = [UzysAppearanceConfig sharedConfig];
    
    UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithImage:[UIImage Uzys_imageNamed:appearanceConfig.closeImageName] style:UIBarButtonItemStyleDone target:self action:@selector(onClose:)];
    // 设置不让titleView偏移
    UIBarButtonItem *right = [[UIBarButtonItem alloc] initWithTitle:@"      " style:UIBarButtonItemStyleDone target:self action:nil];
    self.navigationItem.leftBarButtonItem = left;
    self.navigationItem.rightBarButtonItem = right;

    
    self.mTitleView = [[[NSBundle mainBundle] loadNibNamed:@"UzysTitleView" owner:self options:nil] objectAtIndex:0];
    [self.mTitleView addTarget:self action:@selector(onToggleGroupView:) forControlEvents:UIControlEventTouchUpInside];
    
    CGFloat w = 44;
    UIView *leftItemView = [left valueForKey:@"view"];
    if (leftItemView) {
        w = leftItemView.frame.size.width;
    }
    
    CGFloat newWidth = self.mTitleView.frame.size.width - w;
    CGRect __frame = _mTitleView.frame;
    __frame.size.width = newWidth;
    _mTitleView.frame = __frame;
    
    self.navigationItem.titleView = self.mTitleView;
    
}

- (void)initVariable
{
    [self setAssetsFilter:[ALAssetsFilter allPhotos] type:1];
    self.maximumNumberOfSelection = self.maximumNumberOfSelectionPhoto;
    self.view.clipsToBounds = YES;
    self.orderedSelectedItem = [[NSMutableArray alloc] init];
}


-(void)onToggleGroupView:(UIButton *)sender
{
    [self.groupPicker toggle];
    [self.mTitleView rotateArrow:self.groupPicker.isOpen];
}

-(void)onClose:(UIBarButtonItem *)item {
    
    if([self.delegate respondsToSelector:@selector(uzysAssetsPickerControllerDidCancel:)])
    {
        [self.delegate uzysAssetsPickerControllerDidCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupGroupPickerview
{
    __weak typeof(self) weakSelf = self;
    self.groupPicker = [[UzysGroupPickerView alloc] initWithGroups:self.groups];
    self.groupPicker.blockTouchCell = ^(NSInteger row){
        [weakSelf changeGroup:row];
    };
    
    [self.view addSubview:self.groupPicker];
    [self.view bringSubviewToFront:self.groupPicker];
    [self.mTitleView rotateArrow:self.groupPicker.isOpen];
}

- (void)setupCollectionView
{
    UICollectionViewFlowLayout *layout  = [[UICollectionViewFlowLayout alloc] init];
    UzysAppearanceConfig *appearanceConfig = [UzysAppearanceConfig sharedConfig];
    
    CGFloat itemWidth = ([UIScreen mainScreen].bounds.size.width - appearanceConfig.cellSpacing * ((CGFloat)appearanceConfig.assetsCountInALine - 1.0f)) / (CGFloat)appearanceConfig.assetsCountInALine;
    layout.itemSize = CGSizeMake(itemWidth, itemWidth);
    layout.sectionInset                 = UIEdgeInsetsMake(1.0, 0, 0, 0);
    layout.minimumInteritemSpacing      = 1.0;
    layout.minimumLineSpacing           = appearanceConfig.cellSpacing;
  
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) collectionViewLayout:layout];
    [self.collectionView registerClass:[UzysAssetsViewCell class]
            forCellWithReuseIdentifier:kAssetsViewCellIdentifier];
    //
    [self.collectionView registerClass:[UzysTakePhotoCell class] forCellWithReuseIdentifier:kAssetsViewTakePhotoCellIdentifier];
    
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.bounces = YES;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.scrollsToTop = YES;

    [self.view insertSubview:self.collectionView atIndex:0];
}

#pragma mark - Property
- (void)setAssetsFilter:(ALAssetsFilter *)assetsFilter type:(NSInteger)type
{
    _assetsFilter = assetsFilter;
    _curAssetFilterType = type;
}

#pragma mark - public methods
+ (void)setUpAppearanceConfig:(UzysAppearanceConfig *)config
{
    UzysAppearanceConfig *appearanceConfig = [UzysAppearanceConfig sharedConfig];
    appearanceConfig.assetSelectedImageName = config.assetSelectedImageName;
    appearanceConfig.assetDeselectedImageName = config.assetDeselectedImageName;
    appearanceConfig.cameraImageName = config.cameraImageName;
    appearanceConfig.finishSelectionButtonColor = config.finishSelectionButtonColor;
    appearanceConfig.assetsGroupSelectedImageName = config.assetsGroupSelectedImageName;
    appearanceConfig.closeImageName = config.closeImageName;
    appearanceConfig.assetsCountInALine = config.assetsCountInALine;
    appearanceConfig.cellSpacing = config.cellSpacing;
}

- (void)changeGroup:(NSInteger)item
{
    self.assetsGroup = self.groups[item];
    [self setupAssets:nil];
    [self.groupPicker.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:item inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self.groupPicker dismiss:YES];
    [self.orderedSelectedItem removeAllObjects];
    [self.mTitleView rotateArrow:self.groupPicker.isOpen];
}

// 刷新group
- (void)setupGroup:(voidBlock)endblock withSetupAsset:(BOOL)doSetupAsset
{
    if (!self.assetsLibrary)
    {
        self.assetsLibrary = [self.class defaultAssetsLibrary];
    }
    
    if (!self.groups)
        self.groups = [[NSMutableArray alloc] init];
    else
        [self.groups removeAllObjects];
    
    
    __weak typeof(self) weakSelf = self;
    
    ALAssetsFilter *assetsFilter = self.assetsFilter; // number of Asset 메쏘드 호출 시에 적용.
    
    ALAssetsLibraryGroupsEnumerationResultsBlock resultsBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (group)
        {
            [group setAssetsFilter:assetsFilter];
            NSInteger groupType = [[group valueForProperty:ALAssetsGroupPropertyType] integerValue];
            if(groupType == ALAssetsGroupSavedPhotos)
            {
                [strongSelf.groups insertObject:group atIndex:0]; // 第一个组是`所有照片`
                if(doSetupAsset)
                {
                    strongSelf.assetsGroup = group;
                    [strongSelf setupAssets:nil];
                }
            }
            else
            {
                if (group.numberOfAssets > 0)
                    [strongSelf.groups addObject:group];   // 添加新组
            }
        }
        //traverse to the end, so reload groupPicker.
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.groupPicker reloadData];
                NSUInteger selectedIndex = [weakSelf indexOfAssetGroup:weakSelf.assetsGroup inGroups:weakSelf.groups];
                if (selectedIndex != NSNotFound) {
                    [weakSelf.groupPicker.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedIndex inSection:0] animated:YES scrollPosition:UITableViewScrollPositionNone];
                }
                if(endblock)
                    endblock();
            });
        }
    };
    
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        //접근이 허락 안되었을 경우
        [strongSelf showNotAllowed];
        [strongSelf setTitle:NSLocalizedStringFromTable(@"Not Allowed", @"UzysAssetsPickerController",nil)];
        
    };
    
    [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
                                      usingBlock:resultsBlock
                                    failureBlock:failureBlock];
}

- (void)setupAssets:(voidBlock)successBlock
{
    self.title = [self.assetsGroup valueForProperty:ALAssetsGroupPropertyName];
    
    if (!self.assets)
        self.assets = [[NSMutableArray alloc] init];
    else
        [self.assets removeAllObjects];
    
    if(!self.assetsGroup)
    {
        self.assetsGroup = self.groups[0];
    }
    [self.assetsGroup setAssetsFilter:self.assetsFilter];
    __weak typeof(self) weakSelf = self;
    
    ALAssetsGroupEnumerationResultsBlock resultsBlock = ^(ALAsset *asset, NSUInteger index, BOOL *stop) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (asset)
        {
            [strongSelf.assets addObject:asset];
            
            NSString *type = [asset valueForProperty:ALAssetPropertyType];
            
            if ([type isEqual:ALAssetTypePhoto])
                strongSelf.numberOfPhotos ++;
            if ([type isEqual:ALAssetTypeVideo])
                strongSelf.numberOfVideos ++;
        }
        
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self reloadData];
                if(successBlock)
                    successBlock();
                
            });
        }
    };
    [self.assetsGroup enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:resultsBlock];
}

- (void)reloadData
{
    [self.collectionView reloadData];
    [self showNoAssetsIfNeeded];
}

#pragma mark - Asset Exception View
- (void)initNoAssetView // 没有多媒体
{
    UIView *noAssetsView    = [[UIView alloc] initWithFrame:self.collectionView.bounds];
    
    CGRect rect             = CGRectInset(self.collectionView.bounds, 10, 10);
    UILabel *title          = [[UILabel alloc] initWithFrame:rect];
    UILabel *message        = [[UILabel alloc] initWithFrame:rect];
    
    title.text              = NSLocalizedStringFromTable(@"No Photos or Videos", @"UzysAssetsPickerController", nil);
    title.font              = [UIFont systemFontOfSize:19.0];
    title.textColor         = [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:153.0/255.0 alpha:1];
    title.textAlignment     = NSTextAlignmentCenter;
    title.numberOfLines     = 5;
    title.tag               = kTagNoAssetViewTitleLabel;
    
    message.text            = NSLocalizedStringFromTable(@"You can sync photos and videos onto your iPhone using iTunes.", @"UzysAssetsPickerController",nil);
    message.font            = [UIFont systemFontOfSize:15.0];
    message.textColor       = [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:153.0/255.0 alpha:1];
    message.textAlignment   = NSTextAlignmentCenter;
    message.numberOfLines   = 5;
    message.tag             = kTagNoAssetViewMsgLabel;
    
    UIImageView *titleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_no_image"]];
    titleImage.contentMode = UIViewContentModeCenter;
    titleImage.tag = kTagNoAssetViewImageView;
    
    [title sizeToFit];
    [message sizeToFit];
    
    title.center            = CGPointMake(noAssetsView.center.x, noAssetsView.center.y - 10 - title.frame.size.height / 2 + 40);
    message.center          = CGPointMake(noAssetsView.center.x, noAssetsView.center.y + 10 + message.frame.size.height / 2 + 20);
    titleImage.center       = CGPointMake(noAssetsView.center.x, noAssetsView.center.y - 10 - titleImage.frame.size.height /2);
    [noAssetsView addSubview:title];
    [noAssetsView addSubview:message];
    [noAssetsView addSubview:titleImage];
    
    [self.collectionView addSubview:noAssetsView];
    self.noAssetView = noAssetsView;
    self.noAssetView.hidden = YES;
}

- (void)showNotAllowed // 没有权限
{
    self.title              = nil;
    
    UIView *lockedView      = [[UIView alloc] initWithFrame:self.collectionView.bounds];
    UIImageView *locked     = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_no_access"]];
    locked.contentMode      = UIViewContentModeCenter;
    
    CGRect rect             = CGRectInset(self.collectionView.bounds, 8, 8);
    UILabel *title          = [[UILabel alloc] initWithFrame:rect];
    UILabel *message        = [[UILabel alloc] initWithFrame:rect];
    
    title.text              = NSLocalizedStringFromTable(@"This app does not have access to your photos or videos.", @"UzysAssetsPickerController",nil);
    title.font              = [UIFont boldSystemFontOfSize:17.0];
    title.textColor         = [UIColor colorWithRed:129.0/255.0 green:136.0/255.0 blue:148.0/255.0 alpha:1];
    title.textAlignment     = NSTextAlignmentCenter;
    title.numberOfLines     = 5;
    
    message.text            = NSLocalizedStringFromTable(@"You can enable access in Privacy Settings.", @"UzysAssetsPickerController",nil);
    message.font            = [UIFont systemFontOfSize:14.0];
    message.textColor       = [UIColor colorWithRed:129.0/255.0 green:136.0/255.0 blue:148.0/255.0 alpha:1];
    message.textAlignment   = NSTextAlignmentCenter;
    message.numberOfLines   = 5;
    
    [title sizeToFit];
    [message sizeToFit];
    
    locked.center           = CGPointMake(lockedView.center.x, lockedView.center.y - locked.bounds.size.height /2 - 20);
    title.center            = locked.center;
    message.center          = locked.center;
    
    rect                    = title.frame;
    rect.origin.y           = locked.frame.origin.y + locked.frame.size.height + 10;
    title.frame             = rect;
    
    rect                    = message.frame;
    rect.origin.y           = title.frame.origin.y + title.frame.size.height + 5;
    message.frame           = rect;
    
    [lockedView addSubview:locked];
    [lockedView addSubview:title];
    [lockedView addSubview:message];
    [self.collectionView addSubview:lockedView];
}

- (void)showNoAssetsIfNeeded
{
    __weak typeof(self) weakSelf = self;
    
    voidBlock setNoImage = ^{
        UIImageView *imgView = (UIImageView *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewImageView];
        imgView.contentMode = UIViewContentModeCenter;
        imgView.image = [UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_no_image"];
        
        UILabel *title = (UILabel *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewTitleLabel];
        title.text = NSLocalizedStringFromTable(@"No Photos", @"UzysAssetsPickerController",nil);
        UILabel *msg = (UILabel *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewMsgLabel];
        msg.text = NSLocalizedStringFromTable(@"You can sync photos onto your iPhone using iTunes.",@"UzysAssetsPickerController", nil);
    };
//    voidBlock setNoVideo = ^{
//        UIImageView *imgView = (UIImageView *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewImageView];
//        imgView.image = [UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_no_video"];
//        DLog(@"no video");
//        UILabel *title = (UILabel *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewTitleLabel];
//        title.text = NSLocalizedStringFromTable(@"No Videos", @"UzysAssetsPickerController",nil);
//        UILabel *msg = (UILabel *)[weakSelf.noAssetView viewWithTag:kTagNoAssetViewMsgLabel];
//        msg.text = NSLocalizedStringFromTable(@"You can sync videos onto your iPhone using iTunes.",@"UzysAssetsPickerController", nil);
//        
//    };
    
    if(self.assets.count == 0)
    {
        self.noAssetView.hidden = NO;
        setNoImage();
//        if(self.segmentedControl.hidden == NO)
//        {
//            if(self.segmentedControl.selectedSegmentIndex ==0)
//            {
//                setNoImage();
//            }
//            else
//            {
//                setNoVideo();
//            }
//        }
//        else
//        {
//            if(self.maximumNumberOfSelectionMedia >0)
//            {
//                UIImageView *imgView = (UIImageView *)[self.noAssetView viewWithTag:kTagNoAssetViewImageView];
//                imgView.image = [UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_no_image"];
//                DLog(@"no media");
//                UILabel *title = (UILabel *)[self.noAssetView viewWithTag:kTagNoAssetViewTitleLabel];
//                title.text = NSLocalizedStringFromTable(@"No Videos", @"UzysAssetsPickerController",nil);
//                UILabel *msg = (UILabel *)[self.noAssetView viewWithTag:kTagNoAssetViewMsgLabel];
//                msg.text = NSLocalizedStringFromTable(@"You can sync media onto your iPhone using iTunes.",@"UzysAssetsPickerController", nil);
//                
//            }
//            else if(self.maximumNumberOfSelectionPhoto == 0)
//            {
//                setNoVideo();
//            }
//            else if(self.maximumNumberOfSelectionVideo == 0)
//            {
//                setNoImage();
//            }
//        }
    }
    else
    {
        self.noAssetView.hidden = YES;
    }
}


#pragma mark - Collection View Data Source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.assets.count + 1;
}

// 配置Cell
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        UzysTakePhotoCell *takePhotoCell = [collectionView dequeueReusableCellWithReuseIdentifier:kAssetsViewTakePhotoCellIdentifier forIndexPath:indexPath];
        [takePhotoCell setupViews];
        return takePhotoCell;
    }
    
    static NSString *CellIdentifier = kAssetsViewCellIdentifier;
    UzysAssetsViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    [cell applyData:[self.assets objectAtIndex:indexPath.row - 1]];
    
    return cell;
}

#pragma mark - Collection View Delegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

// selecte
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self openCamera];
        return;
    }
    ALAsset *selectedAsset = [self.assets objectAtIndex:indexPath.item - 1];
    // 裁剪照片
    [self showCropViewController:selectedAsset];
}

-(void)showCropViewController:(ALAsset *)asset
{
    CGImageRef ref = [[asset defaultRepresentation] fullScreenImage];
    
    TRCropViewController *vc = [[TRCropViewController alloc] initWithImage: [UIImage imageWithCGImage:ref]];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Cropper Delegate -

-(void)cropViewController:(TRCropViewController *)cropViewController didFinishCancelled:(BOOL)cancelled
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)cropViewController:(TRCropViewController *)cropViewController didCropToImage:(UIImage *)image withRect:(CGRect)cropRect angle:(NSInteger)angle
{
    [self.delegate uzysAssetsPickerController:self didFinishPickingAssets:@[image]];
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Helper methods
- (NSDictionary *)queryStringToDictionaryOfNSURL:(NSURL *)url
{
    NSArray *urlComponents = [url.query componentsSeparatedByString:@"&"];
    if (urlComponents.count <= 0)
    {
        return nil;
    }
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    for (NSString *keyValuePair in urlComponents)
    {
        NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
        [queryDict setObject:pairComponents[1] forKey:pairComponents[0]];
    }
    return [queryDict copy];
}

// get the group index by current select group
- (NSUInteger)indexOfAssetGroup:(ALAssetsGroup *)group inGroups:(NSArray *)groups
{
    NSString *targetGroupId = [group valueForProperty:ALAssetsGroupPropertyPersistentID];
    __block NSUInteger index = NSNotFound;
    [groups enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ALAssetsGroup *g = obj;
        NSString *gid = [g valueForProperty:ALAssetsGroupPropertyPersistentID];
        if ([gid isEqualToString:targetGroupId])
        {
            index = idx;
            *stop = YES;
        }
        
    }];
    return index;
}

- (NSString *)getUTCFormattedDate:(NSDate *)localDate {
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
    }
    NSString *dateString = [dateFormatter stringFromDate:localDate];
    return dateString;
}

#pragma mark - Notification

//- (void)assetsLibraryUpdated:(NSNotification *)notification
//{
    //recheck here
//    if(![notification.name isEqualToString:ALAssetsLibraryChangedNotification])
//    {
//        return ;
//    }
//    __weak typeof(self) weakSelf = self;
//    dispatch_async(dispatch_get_main_queue(), ^{
//        __strong typeof(self) strongSelf = weakSelf;
//        NSDictionary* info = [notification userInfo];
//        NSSet *updatedAssets = [info objectForKey:ALAssetLibraryUpdatedAssetsKey];
//        NSSet *updatedAssetGroup = [info objectForKey:ALAssetLibraryUpdatedAssetGroupsKey];
//        NSSet *deletedAssetGroup = [info objectForKey:ALAssetLibraryDeletedAssetGroupsKey];
//        NSSet *insertedAssetGroup = [info objectForKey:ALAssetLibraryInsertedAssetGroupsKey];
//        DLog(@"-------------+");
//        DLog(@"updated assets:%@", updatedAssets);
//        DLog(@"updated asset group:%@", updatedAssetGroup);
//        DLog(@"deleted asset group:%@", deletedAssetGroup);
//        DLog(@"inserted asset group:%@", insertedAssetGroup);
//        DLog(@"-------------=");
//        
//        if(info == nil)
//        {
//            //AllClear
//            [strongSelf setupGroup:nil withSetupAsset:YES];
//            return;
//        }
//        
//        if(info.count == 0)
//        {
//            return;
//        }
//        
//        if (deletedAssetGroup.count > 0 || insertedAssetGroup.count > 0 || updatedAssetGroup.count >0)
//        {
//            BOOL currentAssetsGroupIsInDeletedAssetGroup = NO;
//            BOOL currentAssetsGroupIsInUpdatedAssetGroup = NO;
//            NSString *currentAssetGroupId = [strongSelf.assetsGroup valueForProperty:ALAssetsGroupPropertyPersistentID];
//            //check whether user deleted a chosen assetGroup.
//            for (NSURL *groupUrl in deletedAssetGroup)
//            {
//                NSDictionary *queryDictionInURL = [strongSelf queryStringToDictionaryOfNSURL:groupUrl];
//                if ([queryDictionInURL[@"id"] isEqualToString:currentAssetGroupId])
//                {
//                    currentAssetsGroupIsInDeletedAssetGroup = YES;
//                    break;
//                }
//            }
//            for (NSURL *groupUrl in updatedAssetGroup)
//            {
//                NSDictionary *queryDictionInURL = [strongSelf queryStringToDictionaryOfNSURL:groupUrl];
//                if ([queryDictionInURL[@"id"] isEqualToString:currentAssetGroupId])
//                {
//                    currentAssetsGroupIsInUpdatedAssetGroup = YES;
//                    break;
//                }
//            }
//            
//            if (currentAssetsGroupIsInDeletedAssetGroup || [strongSelf.assetsGroup numberOfAssets]==0)
//            {
//                //if user really deletes a chosen assetGroup, make it self.groups[0] to be default selected.
//                [strongSelf setupGroup:^{
//                    [strongSelf.groupPicker reloadData];
//                    [strongSelf.groupPicker.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
//                } withSetupAsset:YES];
//                return;
//            }
//            else
//            {
//                if(currentAssetsGroupIsInUpdatedAssetGroup)
//                {
//                    NSMutableArray *selectedItems = [NSMutableArray array];
//                    NSArray *selectedPath = strongSelf.collectionView.indexPathsForSelectedItems;
//                    
//                    for (NSIndexPath *idxPath in selectedPath)
//                    {
//                        [selectedItems addObject:[strongSelf.assets objectAtIndex:idxPath.row - 1]];
//                    }
//                    NSInteger beforeAssets = strongSelf.assets.count;
//                    [strongSelf setupAssets:^{
//                        for (ALAsset *item in selectedItems)
//                        {
//                            BOOL isExist = false;
//                            for(ALAsset *asset in strongSelf.assets)
//                            {
//                                if([[[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString] isEqualToString:[[item valueForProperty:ALAssetPropertyAssetURL] absoluteString]])
//                                {
//                                    // 重选
//                                    NSUInteger idx = [strongSelf.assets indexOfObject:asset];
//                                    NSIndexPath *newPath = [NSIndexPath indexPathForRow:idx inSection:0];
//                                    [strongSelf.collectionView selectItemAtIndexPath:newPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
//                                    isExist = true;
//                                }
//                            }
//                            if(isExist ==false)
//                            {
//                                [strongSelf.orderedSelectedItem removeObject:item];
//                            }
//                        }
//                        
//                        if(strongSelf.assets.count > beforeAssets)
//                        {
//                            [strongSelf.collectionView setContentOffset:CGPointMake(0, 0) animated:NO];
//                        }
//                        
//                    }];
//                    [strongSelf setupGroup:^{
//                        [strongSelf.groupPicker reloadData];
//                    } withSetupAsset:NO];
//                }
//                else
//                {
//                    [strongSelf setupGroup:^{
//                        [strongSelf.groupPicker reloadData];
//                    } withSetupAsset:NO];
//                    return;
//                }
//            }
//        }
//    });
//}
#pragma mark - Property
- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    // custom
    [self.mTitleView setTitle:title];
}

-(void)openCamera
{
    TGCameraNavigationController *navigationController = [TGCameraNavigationController newWithCameraDelegate:self];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - TGCameraDelegate
-(void)cameraDidCancel
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)cameraDidSelectAlbumPhoto:(UIImage *)image
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)cameraDidTakePhoto:(UIImage *)image
{
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    
    [self dismissViewControllerAnimated:NO completion:nil];
    [self.delegate uzysAssetsPickerController:self didFinishPickingAssets:@[image]];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void) image:(UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo:(NSDictionary*)info
{
    DLog(@"save image to album!!!");
}


#pragma mark - UIImagerPickerDelegate
//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info // 如果需要保存照片。
//{
//    __weak typeof(self) weakSelf = self;
//    UIImage *image = info[UIImagePickerControllerOriginalImage];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:ALAssetsLibraryChangedNotification object:nil];
//    
//    NSMutableDictionary *metaData = [NSMutableDictionary dictionaryWithDictionary:info[UIImagePickerControllerMediaMetadata]];
//    [self addGPSLocation:metaData];
//    
//    [self.assetsLibrary writeImageToSavedPhotosAlbum:image.CGImage metadata:metaData completionBlock:^(NSURL *assetURL, NSError *error) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [strongSelf saveAssetsAction:assetURL error:error isPhoto:YES];
//        });
//        DLog(@"writeImageToSavedPhotosAlbum");
//    }];
//    [picker dismissViewControllerAnimated:YES completion:^{}];
//}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIViewController Property

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}
- (UIViewController *)childViewControllerForStatusBarHidden
{
    return nil;
}
- (BOOL)prefersStatusBarHidden
{
    return NO;
}
-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

@end
