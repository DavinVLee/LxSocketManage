//
//  LxUdpSocketHelper.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/21.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LxSocketHeader.h"
@interface LxSocketHelper : NSObject
/**
 *@description 获取中文对照
 *@param messageKey 发送消息key值
 *@return 对应注释
 **/
+ (NSString *)lx_socketKeyMsgWithType:(LxSocketMessageKey)messageKey;
/**
 *@description 获取字符对照
 **/
+ (NSString *)lx_strWithInfoKey:(NSInteger)infoKey;
@end
