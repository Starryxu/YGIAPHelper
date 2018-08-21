//
//  YGIAPHelper.m
//  YGIAPHelper
//
//  Created by 许亚光 on 2018/8/16.
//  Copyright © 2018年 xuyagung. All rights reserved.
//

#import <StoreKit/StoreKit.h>
#import "YGIAPHelper.h"

//内购恢复过程
typedef NS_ENUM(NSInteger, ENUMRestoreProgress) {
    ENUMRestoreProgressStop = 0, //尚未开始请求
    ENUMRestoreProgressStart = 1, //开始请求
    ENUMRestoreProgressUpdatedTransactions = 2, //更新了事务
    ENUMRestoreProgressFinish = 3, //完成请求
};

@interface YGIAPHelper () <SKPaymentTransactionObserver, SKProductsRequestDelegate> {
    NSString *_productId;
    IAPCompletionHandle _handle;
}

//判断一份交易获得验证的次数  key为随机值
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *transactionCountMap;
//需要验证的支付事务
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<SKPaymentTransaction *> *> *transactionFinishMap;

@property(nonatomic,assign)ENUMRestoreProgress restoreProgress;

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
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue:updatedTransactions:方法
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)addTransactionObserver {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)removeTransactionObserver {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - public method
//开始购买
- (void)startPurchaseWithProductId:(NSString *)productId completeHandle:(IAPCompletionHandle)handle {
    if (productId) {
        if ([SKPaymentQueue canMakePayments]) {
            _productId = productId;
            _handle = handle;
            NSSet *set = [NSSet setWithArray:@[productId]];
            SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
            request.delegate = self;
            [request start];
        } else {
            [self handleActionWithType:SIAPPurchNotArrow data:nil];
        }
    } else {
        [self handleActionWithType:SIAPPurchEmptyID data:nil];
    }
}


- (void)startSubscribeWithProductId:(NSString *)productId password:(NSString *)password completeHandle:(IAPCompletionHandle)handle {
    _password = password;
    [self startPurchaseWithProductId:productId completeHandle:handle];
}


//恢复购买
- (void)restorePurchasesWithCompleteHandle:(IAPCompletionHandle)handle {
    //开始恢复
    _restoreProgress = ENUMRestoreProgressStart;
    _handle = handle;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - SKPaymentTransactionObserver
// 队列操作后的回调
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
                NSLog(@"已经购买过商品");
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

// 恢复购买结束回调
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    // 没有进入- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions 方法
    // 恢复产品数量为0  提前结束
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:SIAPPurchRestoreNotBuy data:nil];
    }
    _restoreProgress = ENUMRestoreProgressFinish;
}

// 恢复购买失败
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    //恢复失败
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:SIAPPurchRestoreFailed data:@{@"error":error.localizedDescription}];
    }
    _restoreProgress = ENUMRestoreProgressFinish;
    
}


#pragma mark - transaction action
// 恢复购买
- (void)restoreTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
}

// 完成交易
- (void)completeTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
}

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:SIAPPurchFailed data:@{@"error":transaction.error.localizedDescription}];
    } else {
        [self handleActionWithType:SIAPPurchCancle data:nil];
    }
}

// 交易验证
- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag operationId:(NSString *)operationId {
    
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if (!receipt) {
        // 交易凭证为空验证失败
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
        return;
    }
    
    NSDictionary *receiptDict = [NSJSONSerialization JSONObjectWithData:receipt options:0 error:nil];
    // 购买成功将交易凭证发送给服务端进行再次校验
    [self handleActionWithType:SIAPPurchSuccess data:receiptDict];
    
    NSError *error;
    NSDictionary *requestContents;
    if (_password) {
        requestContents = @{@"receipt-data": [receipt base64EncodedStringWithOptions:0], @"password":_password};
    } else {
        requestContents = @{@"receipt-data": [receipt base64EncodedStringWithOptions:0]};
    }
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
    
    // 交易凭证为空验证失败
    if (!requestData) {
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
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
            // 无法连接服务器,购买校验失败
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleActionWithType:SIAPPurchVerFailed data:nil];
            });
        } else {
            NSError *error;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!jsonResponse) {
                // 苹果服务器校验数据返回为空校验失败
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleActionWithType:SIAPPurchVerFailed data:nil];
                });
            }
            
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
             ****************************************************************************/
            
            // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
            NSString *status = [NSString stringWithFormat:@"%@", jsonResponse[@"status"]];
            if (status && [status isEqualToString:@"21007"]) {
                [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES operationId:operationId];
            } else if (status && [status isEqualToString:@"0"]) {
                // 订单校验成功
                // APP添加商品
                NSString *productId = transaction.payment.productIdentifier;
                NSLog(@"\n\n===============>> 购买成功ID:%@ <<===============\n\n",productId);
                // 订单总数量
                NSInteger totalCount = [[self.transactionCountMap valueForKey:operationId] integerValue];
                // 已执行数量
                NSMutableSet *finishSet = [self.transactionFinishMap valueForKey:operationId];
                [finishSet addObject:transaction];
                // 需在添加对象后获得对象数量 不然有极低的可能遇到并发问题 而导致不执行回调
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleActionWithType:SIAPPurchVerSuccess data:jsonResponse invokeHandle:[finishSet count]  == totalCount];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleActionWithType:SIAPPurchVerFailed data:nil];
                });
            }
            NSLog(@"----验证结果 %@", jsonResponse);
        }
    }];
    
    [task resume];
}


#pragma mark - SKProductsRequestDelegate
//发送请求后 会回调  执行这个方法
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSArray *products = response.products;
    if ([products count] <= 0) {
        NSLog(@"--------------没有商品------------------");
        [self handleActionWithType:SIAPPurchNoProduct data:nil];
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

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    [self handleActionWithType:SIAPPurchFailed data:@{@"error":error.localizedDescription}];
    NSLog(@"------------------错误-----------------:%@", error);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"------------反馈信息结束-----------------");
}


#pragma mark - private method

//适配器模式
- (void)handleActionWithType:(SIAPPurchType)type data:(NSDictionary *)dict invokeHandle:(Boolean)invoke {
    
#ifdef DEBUG
    switch (type) {
        case SIAPPurchSuccess:
            NSLog(@"购买成功");
            break;
        case SIAPPurchFailed:
            NSLog(@"购买失败");
            break;
        case SIAPPurchCancle:
            NSLog(@"用户取消购买");
            break;
        case SIAPPurchVerFailed:
            NSLog(@"订单校验失败");
            break;
        case SIAPPurchVerSuccess:
            NSLog(@"订单校验成功");
            break;
        case SIAPPurchNotArrow:
            NSLog(@"不允许程序内付费");
            break;
        case SIAPPurchRestoreNotBuy:
            NSLog(@"购买数量为0");
            break;
        case SIAPPurchRestoreFailed:
            NSLog(@"内购恢复失败");
            break;
        case SIAPPurchEmptyID:
            NSLog(@"商品ID为空");
            break;
        case SIAPPurchNoProduct:
            NSLog(@"没有可购买商品");
            break;
        default:
            break;
    }
#endif
    
    //因为购买成功并不是最后一个步骤 没有意义 不进行处理,需要完成验证
    if (type == SIAPPurchSuccess) {
        return;
    }
    
    if (invoke && _handle) {
        _handle(type, dict);
    }
}

//完成回调 自己的block
- (void)handleActionWithType:(SIAPPurchType)type data:(NSDictionary *)dict {
    [self handleActionWithType:type data:dict invokeHandle:true];
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
