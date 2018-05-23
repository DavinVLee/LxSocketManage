//
//  LxSocketServerManage.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/15.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LxSocketHeader.h"
@class LxSocketClientModel;
@interface LxSocketServerManage : NSObject<LxsocketDelegate>
/** 服务端代理 **/
@property (weak, nonatomic) id <LxsocketDelegate> delegate;
/**
 *@description 获取对应客户端model
 **/
+ (LxSocketClientModel *)lx_clientModelWithClientID:(NSString *)clientID;
/**
 *@description 开始作为服务端连接
 *@param clientModels 所有可连接客户端id model
 **/
- (void)lx_connectAsServerHostWithAvaliableClientModels:(NSMutableArray <LxSocketClientModel *>*)clientModels;
/**
 *@description 向所有客户端发送消息
 **/
- (void)lx_tcpSendMessage:(NSString *)message;
@end
