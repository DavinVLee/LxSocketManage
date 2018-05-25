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
///**
// *@description 获取对应客户端model
// **/
//+ (LxSocketClientModel *)lx_clientModelWithClientID:(NSString *)clientID;
/**
 *@description 开始作为服务端连接
 *@param clientModels 所有可连接客户端id model
 **/
- (void)lx_connectAsServerHostWithAvaliableClientModels:(NSMutableArray <LxSocketClientModel *>*)clientModels;
/**
 *@description 向客户端发送消息
 *@param message 发送内容
 *@param msgSync 是否同步（即客户端在一定延时后进行分发后的操作）
 *@param auxiliaryInfo 附属添加的发送消息
 *@param specialDesID 发送方ID集合，若为nil则全部客户端发送
 **/
- (void)lx_tcpSendMessage:(NSString *)message
                  msgSync:(BOOL)msgSync
            auxiliaryInfo:(NSDictionary *)auxiliaryInfo
             specialDesID:(NSArray <NSString *>*)specialDesID;
/**
 *@description 清空并关闭
 **/
- (void)reClearSet;
@end
