//
//  LxSocketHeader.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/21.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#ifndef LxSocketHeader_h
#define LxSocketHeader_h
/** tcp连接端口 **/
#define LxStcp_port 8989
/** udp连接端口 **/
#define LxSudp_port 9999
/** 心跳包发送间隔 **/
#define LxSheartBeatTimeIntravl 2.f

@protocol LxsocketDelegate <NSObject>
@optional
/**
 *@description 获取tcp消息
 *@param messageInfo 实际消息内容
 **/
- (void)receivedMessageInfo:(NSDictionary *)messageInfo;
/**
 *@description 心跳包消息
 **/
- (void)receiveHeartBeat:(NSString *)message fromID:(NSString *)fromID;
/** 发送一次消息 **/
- (void)sentMsgCountOnce;
/** tcp连接掉线一次 **/
- (void)tcpConnectLost;

@end

/** udp收发消息类型->LxSocketInfoMsgType **/
typedef NS_ENUM(NSInteger,LxSocketSendMessageType)
{
    /** 请求服务端IP **/
    LxSocketSendMessageIpRequest = 0,
    /** 服务端通知IP **/
    LxSocketSendMessageServerIp  = 1,
    
    /** 常用发送消息 **/
    LxSocketSendMessageNormal    = 2,
    
    /** 心跳包发送 **/
    LxSocketSendMessageHeartBeat = 3,
    /** 心跳包收到回复 **/
    LxSocketSendMessageHeartReply = 4,
    
    /** 服务端索要id做标签 **/
    LxSocketSendMessageClientIdRequest = 5,
    /** 回复服务端id标识 **/
    LxSocketSendMessageClientIdReply = 6,

};
/** 发送消息key **/
typedef NS_ENUM(NSInteger,LxSocketMessageKey)
{
    /** 发送内容 **/
    LxSocketInfoMsg = 0,
    /** 发送时间 **/
    LxSocketInfoSendTime = 1,
    /** 发送方ID **/
    LxSocketInfoUserID = 2,
    /** 发送消息类型 **/
    LxSocketInfoMsgType = 3,
    /** 发送方IP地址 **/
    LxSocketInfoIP     = 4,
    
        /******************************************************针对课堂添加枚举***************************************************************/
    
    /** 发送消息至客户端后是否同步（延迟执行） **/
    LxSocketInfoSync   = 5,
    /** targetid（课程id） **/
    LxSocketInfoTargetID = 6,
    /** classid(班级id） **/
    LxSocketInfoClassID = 7,
    
};

#endif /* LxSocketHeader_h */
