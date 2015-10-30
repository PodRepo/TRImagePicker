//
//  UzysTitleView.m
//  TRPet
//
//  Created by wyr on 15/8/20.
//  Copyright (c) 2015年 taro. All rights reserved.
//

#import "UzysTitleView.h"

@interface UzysTitleView()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIImageView *arrowImageView;
@end

@implementation UzysTitleView

-(void)awakeFromNib
{
    self.backgroundColor = [UIColor clearColor];
}

-(void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

-(void)rotateArrow:(BOOL)isRotate
{
    [UIView animateWithDuration:0.35 animations:^{
        if(isRotate)
        {
            self.arrowImageView.transform = CGAffineTransformMakeRotation(M_PI);
        }
        else
        {
            self.arrowImageView.transform = CGAffineTransformIdentity;
        }
    } completion:^(BOOL finished) {
    }];

}

@end
