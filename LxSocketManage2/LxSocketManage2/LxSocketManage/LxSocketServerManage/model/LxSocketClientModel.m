//
//  LxSocketClientModel.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/23.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxSocketClientModel.h"

@implementation LxSocketClientModel
/** 获取model **/
+ (LxSocketClientModel *)lx_modelWithClientID:(NSString *)clientID
{
    LxSocketClientModel *client = [[LxSocketClientModel alloc] init];
    client.clientID = [clientID copy];
    return client;
}
@end
