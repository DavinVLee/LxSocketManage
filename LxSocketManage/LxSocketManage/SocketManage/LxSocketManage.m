//
//  LxSocketManage.m
//  LxSocketManage
//
//  Created by 李翔 on 16/11/1.
//  Copyright © 2016年 李翔. All rights reserved.
//

#import "LxSocketManage.h"
#import "CocoaAsyncSocket.h"
#import "IPAddressManage.h"
@interface LxSocketManage ()<GCDAsyncSocketDelegate>

/**
 * 当前主要socket连接
 */
@property (strong, nonatomic) GCDAsyncSocket *socket;
/**
 * 当前已连接socket容器
 */
@property (strong, nonatomic) NSMutableArray <LxSocketModel *>*socketModelArray;

@end

@implementation LxSocketManage

#pragma mark - GetMethod
+ (instancetype)sharedInstance
{
    static LxSocketManage *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSMutableArray *)socketModelArray
{
    if (!_socketModelArray) {
        _socketModelArray = [NSMutableArray array];
    }
    return _socketModelArray;
}

#pragma mark - CallFunction
- (BOOL)createConnectWithHost:(NSString *)host
{
    NSString *ipAddress = [IPAddressManage getIPAddress:NO];
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                             delegateQueue:dispatch_get_main_queue()];
    BOOL initSuccess = NO;
    if ([host isEqualToString:ipAddress]) {
       initSuccess = [self.socket acceptOnPort:LxSocketPort error:nil];
        self.type = SocketServer;
    }else
    {
       initSuccess = [self.socket connectToHost:host
                                         onPort:LxSocketPort
                                          error:nil];
        self.type = SocketClient;
    }
    
    return initSuccess;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"客户端--写入数据完成");
    [sock readDataWithTimeout:-1 tag:1];
}

- (void)sendMessage:(NSString *)msg type:(SocketSendMsgType )type
{
    NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    if (self.type == SocketServer) {
        for (LxSocketModel *model in self.socketModelArray) {
            [model.socket writeData:msgData withTimeout:1 tag:type];
            [model.socket readDataWithTimeout:-1 tag:0];
        }
    }else
    {
        [self.socket writeData:msgData withTimeout:1 tag:type];
        [self.socket readDataWithTimeout:-1 tag:0];
    }
    
}

#pragma mark - SocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *msgStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"收到消息%@",msgStr);
    switch (tag) {
        case SocketSendMsgNormal:
        {
            if (self.type == SocketServer) {
                for (LxSocketModel *model in self.socketModelArray) {
                    if (model.socket != sock) {
                        [model.socket writeData:data withTimeout:-1 tag:tag];
                    }else
                    {
                        NSData *callBackData = [@"成功收到信息" dataUsingEncoding:NSUTF8StringEncoding];
                        [model.socket writeData:callBackData withTimeout:1 tag:SocketSendMsgReceiveCallBack];
                    }
                }
            }
            if ([_delegate respondsToSelector:@selector(didReceiveMsg:)]){
                [_delegate didReceiveMsg:msgStr];
            }
        }
            break;
            case SocketSendMsgReceiveCallBack:
        {
            NSLog(@"成功收到回调");
        }
        default:
            break;
    }

}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"服务端--新的连接");
    LxSocketModel *model = [[LxSocketModel alloc] init];
    model.socket = newSocket;
    model.ipAddress = newSocket.localHost;
    [self.socketModelArray addObject:model];
    [sock readDataWithTimeout:-1 tag:0];
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"客户端--已经连接到%@:%d",host,port);
}

@end
