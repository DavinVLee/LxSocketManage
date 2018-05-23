//
//  LxSocketClientManage.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/15.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LxSocketHeader.h"
@interface LxSocketClientManage : NSObject <LxsocketDelegate>
/** 服务端代理 **/
@property (weak, nonatomic) id <LxsocketDelegate> delegate;
/**
 *@description 开始搜寻并连接服务端
 *@param userId 作为客户端唯一标识
 **/
- (void)lx_connectAsClientWithUserId:(NSString *)userId;
/**
 *@description 向服务端发送消息
 **/
- (void)lx_tcpSendMessage:(NSString *)message;
@end
