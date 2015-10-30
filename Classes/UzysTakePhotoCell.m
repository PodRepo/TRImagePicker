//
//  UzysTakePhotoCell.m
//  LibraryDemo
//
//  Created by wyr on 15/8/18.
//  Copyright (c) 2015年 taro. All rights reserved.
//

#import "UzysTakePhotoCell.h"
#import "UIImage+UzysExtension.h"
#import "Masonry.h"

@interface UzysTakePhotoCell()
@property (strong, nonatomic) UIImageView *mTitleImage;
@property(assign, nonatomic) BOOL ininted;
@end
@implementation UzysTakePhotoCell

- (void)awakeFromNib {
    // Initialization code

}

-(void)setupViews
{
    if (!_ininted) {
        _mTitleImage = [[UIImageView alloc] initWithImage:[UIImage Uzys_imageNamed:@"uzysAP_ico_upload_camera"]];
        [self.contentView addSubview:_mTitleImage];
        
        [_mTitleImage mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView.mas_top).with.offset(0); //with is an optional semantic filler
            make.left.equalTo(self.contentView.mas_left).with.offset(0);
            make.bottom.equalTo(self.contentView.mas_bottom).with.offset(0);
            make.right.equalTo(self.contentView.mas_right).with.offset(0);
        }];
        
        _ininted = YES;
    }


//    UIImageView *background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UzysAssetPickerController.bundle/uzysAP_ico_upload_camera@2x.png"]];
//    background.contentMode = UIViewContentModeCenter;
//    background.frame = self.contentView.frame;
////    background.backgroundColor = [UIColor blueColor];
////    background.alpha = 0.7;
//
//    [self.contentView addSubview:background];
}

@end
