//
//  YGIAPHelper.m
//  YGIAPHelper
//
//  Created by 许亚光 on 2018/8/16.
//  Copyright © 2018年 xuyagung. All rights reserved.
//

/** 打印 **/
#if DEBUG
#define NSLog(FORMAT, ...)\
fprintf(stderr,"✅✅✅:%s line:%d content:%s\n", __FUNCTION__, __LINE__, [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(FORMAT, ...) nil
#endif


#import <StoreKit/StoreKit.h>
#import "YGIAPHelper.h"
#import "YGPrisonBreakCheck.h"

// 内购恢复过程
typedef NS_ENUM(NSInteger, ENUMRestoreProgress) {
    ENUMRestoreProgressStop = 0, //尚未开始请求
    ENUMRestoreProgressStart = 1, //开始请求
    ENUMRestoreProgressUpdatedTransactions = 2, //更新了事务
    ENUMRestoreProgressFinish = 3, //完成请求
};

@interface YGIAPHelper () <SKPaymentTransactionObserver, SKProductsRequestDelegate>

/** 回调Block */
@property (nonatomic, copy) IAPCompletionHandle handle;
/** 要购买的产品ID */
@property (nonatomic, copy) NSString *productId;
/** App专用共享密钥, 有订阅时必须传此参数 */
@property (nonatomic, copy) NSString *password;

//判断一份交易获得验证的次数  key为随机值
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *transactionCountMap;
//需要验证的支付事务
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<SKPaymentTransaction *> *> *transactionFinishMap;

@property (nonatomic, assign) ENUMRestoreProgress restoreProgress;


@end

@implementation YGIAPHelper

+ (instancetype)sharedInstance {
    static YGIAPHelper *_IAPInstabce = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _IAPInstabce = [[YGIAPHelper alloc] init];
    });
    return _IAPInstabce;
}

- (instancetype)init {
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}



#pragma mark - public method
//开始购买
- (void)startPurchaseWithProductId:(NSString *)productId password:(NSString *)password completeHandle:(IAPCompletionHandle)handle {
    if ([YGPrisonBreakCheck prisonBreakCheck]) { // 判断是否是越狱手机
        [self handleActionWithType:IAPPurchPrisonCellPhone data:nil];
        return;
    }
    
    if (!productId) { // 判断传入的产品ID是否为空
        [self handleActionWithType:IAPPurchEmptyID data:nil];
        return;
    }
    
    if ([SKPaymentQueue canMakePayments]) {
        _productId = productId;
        _password = password;
        _handle = handle;
        NSSet *set = [NSSet setWithArray:@[productId]];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
        request.delegate = self;
        [request start];
    } else {
        [self handleActionWithType:IAPPurchNotArrow data:nil];
    }
    
}


#pragma mark - 恢复购买
- (void)restorePurchasesWithPassword:(NSString *)password completeHandle:(IAPCompletionHandle)handle {
    
    if ([YGPrisonBreakCheck prisonBreakCheck]) { // 判断是否是越狱手机
        [self handleActionWithType:IAPPurchPrisonCellPhone data:nil];
        return;
    }
    
    _restoreProgress = ENUMRestoreProgressStart;
    _password = password;
    _handle = handle;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - SKPaymentTransactionObserver
// 方法1:
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    //判断是否为恢复购买的请求
    if (_restoreProgress == ENUMRestoreProgressStart) {
        _restoreProgress = ENUMRestoreProgressUpdatedTransactions;
    }
    
    NSString *operationId = [[NSUUID UUID] UUIDString];
    
    [self.transactionFinishMap setValue:[NSMutableSet set] forKey:operationId];
    [self.transactionCountMap setValue:@(transactions.count) forKey:operationId];
    
    for (SKPaymentTransaction *tran in transactions) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:{
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                [self completeTransaction:tran operationId:operationId];
            } break;
            case SKPaymentTransactionStatePurchasing:{
                NSLog(@"正在购买");
            } break;
            case SKPaymentTransactionStateRestored:{
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                [self restoreTransaction:tran operationId:operationId];
            } break;
            case SKPaymentTransactionStateFailed:{
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                [self failedTransaction:tran];
            } break;
            default:
                break;
        }
    }
}

// 方法2:当恢复内购成功时先调用方法1,再调用方法2
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:IAPPurchRestoreNotBuy data:nil];
    }
    _restoreProgress = ENUMRestoreProgressFinish;
}

// 方法3:当恢复内购失败时直接调用该方法
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:IAPPurchRestoreFailed data:@{@"error":error.localizedDescription}];
    }
    _restoreProgress = ENUMRestoreProgressFinish;
}


#pragma mark - transaction action
// 恢复购买
- (void)restoreTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
}

// 完成付款
- (void)completeTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
}

// 付款失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:IAPPurchFailed data:@{@"error":transaction.error.localizedDescription}];
    } else {
        [self handleActionWithType:IAPPurchCancle data:nil];
    }
}

// 交易验证
- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag operationId:(NSString *)operationId {
    
    // 获取交易凭证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if (!receipt) {
        [self handleActionWithType:IAPPurchVerFailed data:nil];
        return;
    }
    
    
    NSError *requestError;
    NSDictionary *requestContents = @{@"receipt-data": [receipt base64EncodedStringWithOptions:0], @"password":_password?:@""};

    
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&requestError];
    if (requestError) {
        [self handleActionWithType:IAPPurchVerFailed data:nil];
        return;
    }
    
    // 沙盒环境验证: https://sandbox.itunes.apple.com/verifyReceipt
    // 正式环境验证: https://buy.itunes.apple.com/verifyReceipt
    NSString *serverString;
    if (flag) {
        serverString = @"https://sandbox.itunes.apple.com/verifyReceipt";
    } else {
        serverString = @"https://buy.itunes.apple.com/verifyReceipt";
    }
    
    NSURL *storeURL = [NSURL URLWithString:serverString];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:storeRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleActionWithType:IAPPurchVerFailed data:nil];
            });
            
        } else {
            NSError *responseError;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&responseError];
            if (responseError || !jsonResponse) {
                dispatch_async(dispatch_get_main_queue(), ^{ // 回到主线程
                    [self handleActionWithType:IAPPurchVerFailed data:nil];
                });
            } else {
                
                NSString *status = [NSString stringWithFormat:@"%@", jsonResponse[@"status"]];
                /****************************************************************************
                 验证错误状态码:
                 -> 21000 App Store无法读取你提供的JSON数据
                 -> 21002 收据数据不符合格式
                 -> 21003 收据无法被验证
                 -> 21004 你提供的共享密钥和账户的共享密钥不一致
                 -> 21005 收据服务器当前不可用
                 -> 21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
                 -> 21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
                 -> 21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
                 -> 21100-21199 内部数据访问错误
                 ****************************************************************************/
                
                // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                if (status && [status isEqualToString:@"21007"]) { // 验证沙盒环境
                    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES operationId:operationId];
                    
                } else if (status && [status isEqualToString:@"0"]) { // 验证订单都ID在收据中
                    //APP添加商品
                    NSString *productId = transaction.payment.productIdentifier;
                    
                    NSLog(@"\n\n===============>> 购买成功ID:%@ <<===============\n\n",productId);
                    
                    //总数量
                    NSInteger totalCount = [[self.transactionCountMap valueForKey:operationId] integerValue];
                    
                    //已执行数量
                    NSMutableSet *finishSet = [self.transactionFinishMap valueForKey:operationId];
                    [finishSet addObject:transaction];
                    
                    if ([finishSet count]  == totalCount) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self handleActionWithType:IAPPurchVerSuccess data:jsonResponse];
                        });
                    }
                    
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self handleActionWithType:IAPPurchVerFailed data:nil];
                    });
                }
            }
        }
    }];
    
    [task resume];
}


#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSArray *products = response.products;
    if ([products count] <= 0) {
        NSLog(@"--------------没有商品------------------");
        [self handleActionWithType:IAPPurchNoProduct data:nil];
        return;
    }
    
    SKProduct *p = nil;
    for (SKProduct *pro in products) {
        if ([pro.productIdentifier isEqualToString:_productId]) {
            p = pro;
            break;
        }
    }
    
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu", (unsigned long) [products count]);
    NSLog(@"%@", [p description]);
    NSLog(@"%@", [p localizedTitle]);
    NSLog(@"%@", [p localizedDescription]);
    NSLog(@"%@", [p price]);
    NSLog(@"%@", [p productIdentifier]);
    NSLog(@"发送购买请求");
    
    
    SKPayment *payment = [SKPayment paymentWithProduct:p];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    [self handleActionWithType:IAPPurchFailed data:@{@"error":error.localizedDescription}];
    NSLog(@"------------------错误-----------------:%@", error);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"------------反馈信息结束-----------------");
}


#pragma mark - 自定义方法
- (void)handleActionWithType:(IAPPurchType)type data:(NSDictionary *)dict {
    
    switch (type) {
        case IAPPurchSuccess:
            NSLog(@"购买成功");
            break;
        case IAPPurchFailed:
            NSLog(@"购买失败");
            break;
        case IAPPurchCancle:
            NSLog(@"用户取消购买");
            break;
        case IAPPurchVerFailed:
            NSLog(@"订单校验失败");
            break;
        case IAPPurchVerSuccess:
            NSLog(@"订单校验成功");
            break;
        case IAPPurchNotArrow:
            NSLog(@"不允许程序内付费");
            break;
        case IAPPurchRestoreNotBuy:
            NSLog(@"购买数量为0");
            break;
        case IAPPurchRestoreFailed:
            NSLog(@"内购恢复失败");
            break;
        case IAPPurchEmptyID:
            NSLog(@"商品ID为空");
            break;
        case IAPPurchNoProduct:
            NSLog(@"没有可购买商品");
            break;
        default:
            break;
    }
    
    // 购买成功需要验证
    if (IAPPurchSuccess) {
        return;
    }
    
    if (_handle) {
        _handle(type, dict);
    }
}



#pragma mark - getter & setter
- (NSMutableDictionary *)transactionFinishMap {
    if (!_transactionFinishMap) {
        _transactionFinishMap = [NSMutableDictionary dictionary];
    }
    return _transactionFinishMap;
}


- (NSMutableDictionary *)transactionCountMap {
    if (!_transactionCountMap) {
        _transactionCountMap = [NSMutableDictionary dictionary];
    }
    return _transactionCountMap;
}




@end





