//
//  ViewController.m
//  example
//
//  Created by joshua li on 15/10/29.
//  Copyright © 2015年 joshua li. All rights reserved.
//

#import "ViewController.h"

#import <TRImagePicker/UzysAssetsPickerController.h>

@interface ViewController ()<UzysAssetsPickerControllerDelegate>
@property(strong, nonatomic) UzysAssetsPickerController* vc;
@property (weak, nonatomic) IBOutlet UIImageView *image;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onBtn:(id)sender {
    _vc = [[UzysAssetsPickerController alloc] init];
    _vc.maximumNumberOfSelectionPhoto = 1;
    _vc.delegate = self;
    
    UINavigationController *c = [[UINavigationController alloc] initWithRootViewController:_vc];
    [self presentViewController:c animated:YES completion:nil];
    
}

- (void)uzysAssetsPickerController:(UzysAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)images{
    _image.image = images[0];
}

- (void)uzysAssetsPickerControllerDidCancel:(UzysAssetsPickerController *)picker{
    NSLog(@"cancel");
}
- (void)uzysAssetsPickerControllerDidExceedMaximumNumberOfSelection:(UzysAssetsPickerController *)picker{
    NSLog(@"exced");
}

@end
