//
//  LxSocketClientModel.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/23.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxSocketClientModel.h"

@implementation LxSocketClientModel
/**
*@description 获取model
*@param clientID 客户端ID
*@param clientName 客户端名称
*@return 客户端client
**/
+ (LxSocketClientModel *)lx_modelWithClientID:(NSString *)clientID
clientName:(NSString *)clientName;
{
    LxSocketClientModel *client = [[LxSocketClientModel alloc] init];
    client.clientID = [clientID copy];
    client.clientName = clientName;
    return client;
}
@end
