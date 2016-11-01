//
//  LxSocketConfig.h
//  LxSocketManage
//
//  Created by 李翔 on 16/11/1.
//  Copyright © 2016年 李翔. All rights reserved.
//

#ifndef LxSocketConfig_h
#define LxSocketConfig_h

#import "LxSocketModel.h"

/*
 * 主机IP地址
 */
#define LxSocketHost @"192.168.11.187"
/**
 * 主机端口号
 */
#define LxSocketPort 1024

/**
 * 发送消息类别
 */
typedef NS_ENUM(NSInteger, SocketSendMsgType) {
    SocketSendMsgNormal      = 0,
    SocketSendMsgReceiveCallBack = 1,
};

/**
 * 客户端与服务端类型
 */
typedef NS_ENUM(NSInteger, SocketType) {
    SocketServer = 0,
    SocketClient = 1,
};

#endif /* LxSocketConfig_h */
