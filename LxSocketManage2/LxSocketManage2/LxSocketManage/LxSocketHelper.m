//
//  LxUdpSocketHelper.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/21.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxSocketHelper.h"

@implementation LxSocketHelper

/**
 *@description 获取中文对照
 *@param messageKey 发送消息key值
 *@return 对应注释
 **/
+ (NSString *)lx_socketKeyMsgWithType:(LxSocketMessageKey)messageKey;
{
    switch (messageKey) {
        case LxSocketInfoSendTime:
            return @"发送时间";
            break;
            case LxSocketInfoUserID:
            return @"发送方id";
            break;
            case LxSocketInfoMsg:
            return @"实际发送内容";
            case LxSocketInfoMsgType:
            return @"消息类型";
            break;
            case lxSocketInfoIP:
            return @"发送方IP";
            break;
            default:
            return @"未找到";
            break;
    }
}

+ (NSString *)lx_strWithInfoKey:(NSInteger)infoKey
{
    return [NSString stringWithFormat:@"%ld",infoKey];
}
@end
