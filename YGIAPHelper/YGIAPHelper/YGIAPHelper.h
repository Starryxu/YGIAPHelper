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
    SIAPPurchEmptyID        = 8, // 购买ID为空
    SIAPPurchPrisonCellPhone= 9, // 越狱手机
    SIAPPurchNoProduct      = 10,// 没有可购买商品
};

/**
 * Block回调:1:dict为收据; 2:错误信息@{@"error":@""}
 */
typedef void (^IAPCompletionHandle)(SIAPPurchType type, NSDictionary *dict);


/**
 * 内购产品ID
 *
 * @param products 有效产品ID
 * @param invalidProductIdentifiers 无效产品ID
 */
typedef void (^IAPPaymentsProducts)(NSArray *products, NSArray *invalidProductIdentifiers);

@interface YGIAPHelper : NSObject


/**
 * 获取内购实例
 */
+ (instancetype)sharedInstance;


/**
 * 是否可以购买
 */
- (BOOL)canMakePayments;


/**
 * 获取内购产品ID
 *
 * @param products 产品ID,包括可用和不可用两部分
 */
- (void)getPaymentsProductIDs:(IAPPaymentsProducts)productIDs;



/**
 * 购买
 *
 * @param productId 购买产品ID
 * @param password  App专用共享密钥,有订阅时必须传此参数
 * @param handle    购买状态回调
 */
- (void)startPurchaseWithProductId:(NSString *)productId password:(NSString *)password completeHandle:(IAPCompletionHandle)handle;


/**
 * 恢复内购
 */
- (void)restorePurchasesWithPassword:(NSString *)password completeHandle:(IAPCompletionHandle)handle;


@end

