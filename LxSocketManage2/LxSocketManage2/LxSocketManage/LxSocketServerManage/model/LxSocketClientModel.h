//
//  LxSocketClientModel.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/23.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GCDAsyncSocket;
typedef NS_ENUM(NSInteger,LxSocketConnectStatus)
{
    LxSocketConnectLost = 0,
    lxSocketConnecting = 1,
    LxSocketConnected = 2,
};
@interface LxSocketClientModel : NSObject
/** 客户端名称 **/
@property (copy, nonatomic) NSString *clientName;
/** 客户端ID **/
@property (copy, nonatomic) NSString *clientID;
/** 客户端socket持有 **/
@property (strong, nonatomic) GCDAsyncSocket *socket;
/** 上一次客户端发送心跳包时间戳（由服务端确认心跳包无问题后赋值新的心跳包时间戳） **/
@property (assign, nonatomic) NSTimeInterval lastTimeStamp;
/** 客户端连接状态 **/
@property (assign, nonatomic) LxSocketConnectStatus connectStatus;
/**
 *@description 获取model
 *@param clientID 客户端ID
 *@param clientName 客户端名称
 *@return 客户端client
 **/
+ (LxSocketClientModel *)lx_modelWithClientID:(NSString *)clientID
                                   clientName:(NSString *)clientName;

@end
