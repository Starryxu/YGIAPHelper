//
//  YGPrisonBreakCheck.m
//  YGIAPHelper
//
//  Created by 许亚光 on 2018/8/22.
//  Copyright © 2018年 xuyagung. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YGPrisonBreakCheck.h"

// 常见越狱文件
const char *examineBreak_Tool_pathes[] = {
    "/Applications/Cydia.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/bin/bash",
    "/usr/sbin/sshd",
    "/etc/apt"
};
char *printEnv(void){
    char *env = getenv("DYLD_INSERT_LIBRARIES");
    return env;
    
}

@implementation YGPrisonBreakCheck

+ (BOOL)prisonBreakCheck {
    // 判断是否存在越狱文件
    for (int i = 0; i < 5; i++) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:examineBreak_Tool_pathes[i]]]){
            return YES;
        }
    }
    // 判断是否存在cydia应用
    if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]){
        return YES;
    }
    // 读取系统所有的应用名称
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/User/Applications/"]){
        return YES;
    }
    // 读取环境变量
    if(printEnv()){
        return YES;
    }
    
    return NO;
}

@end
