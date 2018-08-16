//
//  YGIAPHelper.h
//  YGIAPHelper
//
//  Created by 许亚光 on 2018/8/16.
//  Copyright © 2018年 xuyagung. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 购买/恢复 结果类型
 */
typedef NS_ENUM(NSInteger, SIAPPurchType) {
    SIAPPurchSuccess        = 0, // 购买成功
    SIAPPurchFailed         = 1, // 购买失败
    SIAPPurchCancle         = 2, // 取消购买
    SIAPPurchVerFailed      = 3, // 订单校验失败
    SIAPPurchVerSuccess     = 4, // 订单校验成功
    SIAPPurchNotArrow       = 5, // 不允许内购
    SIAPPurchRestoreNotBuy  = 6, // 恢复购买数量为0
    SIAPPurchRestoreFailed  = 7, // 恢复失败
};

/**
 * Block回调
 */
typedef void (^IAPCompletionHandle)(SIAPPurchType type, NSData *data);

@interface YGIAPHelper : NSObject

/**
 * 获取内购实例
 */
+ (instancetype)sharedInstance;


/**
 * 添加内购事物监听,第一次调用时 + (instancetype)sharedInstance默认添加
 */
- (void)addTransactionObserver;


/**
 * 移除内购事物监听,不需要监听时移除
 */
- (void)removeTransactionObserver;

/**
 * 发起内购
 */
- (void)startPurchaseWithProductId:(NSString *)productId completeHandle:(IAPCompletionHandle)handle;

/**
 * 恢复内购
 */
- (void)restorePurchasesWithCompleteHandle:(IAPCompletionHandle)handle;


@end
