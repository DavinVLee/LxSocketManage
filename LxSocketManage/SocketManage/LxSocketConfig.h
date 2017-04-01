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
#import "IPAddressManage.h"

/*
 * 主机IP地址
 */
//#define LxSocketHost @"192.168.11.187"
/**
 * 主机端口号
 */
#define LxSocketPort 1024

/**
 * 发送消息类别
 */
typedef NS_ENUM(NSInteger, SocketSendMsgType) {
    SocketSendMsgNormal      = 1,//正常文本信息
    SocketSendMsgConnectionCheck = 2,//学生想老师发送消息确认是否连接成功
    SocketSendMsgConnectionCheckCallBack = 3,//老师收到学生检测信息后回应
    SocketSendMsgBeatMsg     = 4,//心跳包发送
    SocketSendMsgBeatCallBack = 5,//学生发送心跳包后，客户端回应
    SocketSendMsgConnectSuccessCallBack = 6,//客户端连接成功后由服务端发送反馈确定连接成功
    
    SocketSendMsgCliendIdSet = 7,//学生在连接成功后发送自己的id与ip绑定，方便指定控制规则
    
    SocketSendMsgBeConnectClosed = 8,//老师通知学生关闭连接
    //udp
    SocketSendMsgUDPidCheck  = 9,//客户端收到IP后 发送id验证是否为班级学生
    SocketSendMsgUDPidCheckCallBack = 10,//服务端收到客户端id后，验证是否成功
};

/**
 * 客户端与服务端类型
 */
typedef NS_ENUM(NSInteger, SocketType) {
    SocketServer = 0,
    SocketClient = 1,
};

/**
 * 链接状态
 */
typedef NS_ENUM(NSInteger, SocketStatus){
    SocketClosed    = 0,
    SocketConneting = 1,
    SocketConnetEd  = 2,
};


#endif /* LxSocketConfig_h */
