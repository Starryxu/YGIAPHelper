//
//  ViewController.m
//  YGIAPHelper
//
//  Created by 许亚光 on 2018/8/16.
//  Copyright © 2018年 xuyagung. All rights reserved.
//

#import "ViewController.h"
#import "SVProgressHUD.h"
#import "YGIAPHelper.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    /*
     ///private/var/mobile/Containers/Data/Application/FF75DA60-21C3-4E19-BFFD-19CCA715E7A6/StoreKit/sandboxReceipt
     ///private/var/mobile/Containers/Data/Application/FF75DA60-21C3-4E19-BFFD-19CCA715E7A6/StoreKit/sandboxReceipt
     
     */
   
}

- (IBAction)pay:(UIButton *)sender {
    [SVProgressHUD show];
    [[YGIAPHelper sharedInstance] startPurchaseWithProductId:@"xtool_purchase_test" password:@"06fdccbae70b466ea34ee11790747a34"  completeHandle:^(SIAPPurchType type, NSDictionary *dict) {
        [self handel:type info:dict];
    }];
}

- (IBAction)sub:(UIButton *)sender {
    [SVProgressHUD show];
    [[YGIAPHelper sharedInstance] startPurchaseWithProductId:@"xtools_vip_one_week" password:@"06fdccbae70b466ea34ee11790747a34" completeHandle:^(SIAPPurchType type, NSDictionary *dict) {
        [self handel:type info:dict];
    }];
}

- (IBAction)ret:(UIButton *)sender {
    [SVProgressHUD show];
    [[YGIAPHelper sharedInstance] restorePurchasesWithPassword:@"06fdccbae70b466ea34ee11790747a34" completeHandle:^(SIAPPurchType type, NSDictionary *dict) {
        [self handel:type info:dict];
    }];
}



- (void)handel:(SIAPPurchType)type info:(NSDictionary *)info {
    switch (type) {
        case SIAPPurchCancle:{
            [SVProgressHUD showInfoWithStatus:@"购买取消"];
        } break;
        case SIAPPurchFailed:{
            [SVProgressHUD showErrorWithStatus:@"购买失败"];
        } break;
        case SIAPPurchVerFailed:{
            [SVProgressHUD showErrorWithStatus:@"验证失败"];
        } break;
        case SIAPPurchVerSuccess:{
            [SVProgressHUD showSuccessWithStatus:@"验证成功"];
            NSLog(@"--------------------------------------\n%@",info);
        } break;
        default:
            NSLog(@"%zd",type);
            [SVProgressHUD showInfoWithStatus:@"未知错误"];
            break;
    }
}


@end
