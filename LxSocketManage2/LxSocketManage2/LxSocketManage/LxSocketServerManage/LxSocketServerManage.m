//
//  LxSocketServerManage.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/15.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxSocketServerManage.h"
#import "GCDAsyncSocket.h" // for TCP
#import "GCDAsyncUdpSocket.h" // for UDP
#import "NSObject+Default.h"
#import "LxSocketHelper.h"
#import "LxLogInterface.h"
#import "NSDictionary+Helper.h"
#import "NSString+Helper.h"
#import "IPAddressManage.h"
#import "LxSocketClientModel.h"
@interface LxSocketServerManage()<GCDAsyncUdpSocketDelegate,
GCDAsyncSocketDelegate>
/** TCP连接对象 **/
@property (strong, nonatomic, getter = tcpSocket) GCDAsyncSocket *tcpSocket;
/** UDP连接对象 **/
@property (strong, nonatomic, getter = udpSocket) GCDAsyncUdpSocket *udpSocket;
/** 持有所有客户端对象 **/
@property (strong, nonatomic) NSMutableArray <LxSocketClientModel *>*allClientModels;
/** 临时持有已连接、未确定的clientSocket **/
@property (strong, nonatomic) NSMutableArray <GCDAsyncSocket *>*tempSocketArray;
/****************************************************** dispatch ***************************************************************/
/** udp广播队列 **/
@property (strong, nonatomic) dispatch_queue_t udpQueue;
/** tcp连接队列 **/
@property (strong, nonatomic) dispatch_queue_t tcpQueue;
/** tcp代理队列 **/
@property (strong, nonatomic) dispatch_queue_t tcpDelegateQueue;
/** 检查超时计时器 **/
@property (strong, nonatomic) dispatch_source_t runLoopTime;
@end
@implementation LxSocketServerManage
#pragma mark - ********************  init  ********************
- (instancetype)init
{
    if (self == [super init]) {
        _tempSocketArray = [[NSMutableArray alloc] init];
          _tcpDelegateQueue = dispatch_queue_create("tcpDelegateQueue", DISPATCH_QUEUE_SERIAL);
        _tcpQueue = dispatch_queue_create("tcpSocketQueue", DISPATCH_QUEUE_SERIAL);
        _udpQueue = dispatch_queue_create("udpSocketQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - ********************  GetMethod  ********************
- (GCDAsyncSocket *)tcpSocket
{
    if (!_tcpSocket) {
        
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                delegateQueue:_tcpDelegateQueue
                                                  socketQueue:_tcpQueue];
        _tcpSocket.delegate = self;
    }
    return _tcpSocket;
}
/** udp_get **/
- (GCDAsyncUdpSocket *)udpSocket
{
    if (!_udpSocket) {
        
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithSocketQueue:_udpQueue];
        _udpSocket.delegateQueue = _udpQueue;
        _udpSocket.delegate = self;
    }
    return _udpSocket;
}
#pragma mark - ********************  Call_Function  ********************
- (void)lx_connectAsServerHostWithAvaliableClientModels:(NSMutableArray <LxSocketClientModel *>*)clientModels;
{
    if (clientModels) {
        self.allClientModels = clientModels;
    }
    /** 开始连接 **/
    [self tcp_disconnect];
    [self udp_disconnect];
    [self tcp_connectBegin];
    [self udp_connectBegin];
}
/** 发送消息 **/
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
{
    NSMutableDictionary *msgInfo = [self tcp_defaultMessageInfo];
    [msgInfo setObject:message forKey:[NSString stringWithFormat:@"%ld",LxSocketInfoMsg]];
    [msgInfo setObject:[LxSocketHelper lx_strWithInfoKey:LxSocketSendMessageNormal] forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]];
    if (auxiliaryInfo) {
        for (NSString *auxiKey in auxiliaryInfo) {
            [msgInfo setObject:auxiliaryInfo[auxiKey] forKey:auxiKey];
        }
    }
    [msgInfo setObject:@(msgSync) forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoSync]];
    NSString *jsonMsg = [msgInfo lx_JsonString];
    
    for (LxSocketClientModel *client in self.allClientModels) {
        if (client.socket) {
            [client.socket writeData:[jsonMsg dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:0
                                 tag:0];
            [client.socket readDataWithTimeout:-1 tag:0];
        }
    }
}
#pragma mark - ********************  Function  ********************
- (void)tcp_disconnect
{
    [self stopRunloopTimer];
    /** 提前关闭连接 **/
    if (_tcpSocket) {
        
        _tcpSocket.delegate = nil;
        [_tcpSocket disconnect];
        _tcpSocket = nil;
         [self.tempSocketArray removeAllObjects];
        for (GCDAsyncSocket *socket in self.tempSocketArray) {
            [socket disconnect];
        }
    }
    
}
- (void)udp_disconnect
{
    [self stopRunloopTimer];
    /** 提前关闭连接 **/
    if (_udpSocket) {
        _udpSocket.delegate = nil;
        [_udpSocket close];
        _udpSocket = nil;
    }
}
/** 开始udp连接 **/
- (BOOL)udp_connectBegin
{
    NSError *error;
    /** 开启广播 **/
    [self.udpSocket bindToPort:LxSudp_port error:&error];
    if (error) {NSLog(@"绑定PORT失败%@",error.description); [self reTryHostBind];}
    [self.udpSocket enableBroadcast:YES error:&error];
    if (error) {NSLog(@"启用广播失败%@",error.description); [self reTryHostBind];}
    [self.udpSocket beginReceiving:&error];
    if (error) {NSLog(@"开启接收数据:%@",error); [self reTryHostBind];}
    return error == nil;
}
/** 开始tcp连接 **/
- (BOOL)tcp_connectBegin
{
    NSError *error;
    /** 开启服务端 **/
    BOOL acceptSuccess = [self.tcpSocket acceptOnPort:LxStcp_port error:&error];
    if (error || !acceptSuccess) {
        /*NSLog(@"开启服务端失败%@",error.description);*/
        [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"开启服务端失败%@",error.description]];
        [self reTryHostBind];
    }
    else
    {
       [self.tcpSocket readDataWithTimeout:-1 tag:0];
    }
    return error == nil;
}
/** 因socket绑定或初始化出问题后的延时重新绑定 **/
- (void)reTryHostBind
{
    [self stopRunloopTimer];
    [self tcp_disconnect];
    [self udp_disconnect];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(lx_connectAsServerHostWithAvaliableClientModels:) withObject:nil afterDelay:LxSheartBeatTimeIntravl * 0.75];
        [[LxLogInterface sharedInstance] logWithStr:@"重新进行一次连接"];
    });
   
}
/** 关闭计时器 **/
- (void)stopRunloopTimer
{
    if (self.runLoopTime) {
        dispatch_cancel(self.runLoopTime);
        self.runLoopTime = nil;
    }
}
/** 开始关于客户端心跳包是否及时发送问题 **/
- (void)startClientHeartBeatCircle
{
    [self stopRunloopTimer];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.runLoopTime = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.runLoopTime,DISPATCH_TIME_NOW,( LxSheartBeatTimeIntravl + 0.5)*NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(self.runLoopTime, ^{
        [self checkClientsHeartBeat];
    });
    dispatch_resume(self.runLoopTime);
}
/** 检查每个客户端心跳包是否及时发送 **/
- (void)checkClientsHeartBeat
{
    NSTimeInterval timeNow = [[NSDate date] timeIntervalSince1970];
    for (LxSocketClientModel *client in self.allClientModels) {
        if (client.connectStatus == LxSocketConnected) {
            if (timeNow - client.lastTimeStamp > LxSheartBeatTimeIntravl) {
                
            }
        }else if (client.connectStatus == LxSocketConnectLost)
        {
            
        }
    }
}
/** 检查是否含有该广播id **/
- (BOOL)checkExistClientID:(NSString *)clientID
{
    for (LxSocketClientModel *client in self.allClientModels) {
        if ([client.clientID isEqualToString:clientID]) {
            return YES;
        }
    }
    return NO;
}
#pragma mark - ********************  ClientModelAbout  ********************
- (void)removeSocket:(GCDAsyncSocket *)socket
{
    [socket disconnect];
    if ([self.tempSocketArray containsObject:socket]) {
        [self.tempSocketArray removeObject:socket];
    }else if (socket == self.tcpSocket)
    {
        [self reTryHostBind];
    }
    for (LxSocketClientModel *client in self.allClientModels) {
        if ([[client.socket lx_objcAddress] isEqualToString:[socket lx_objcAddress]]) {
            client.socket = nil;
            client.connectStatus = LxSocketConnectLost;
            [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"移除id:%@",client.clientID]];
        }
    }
}
- (void)addSocket:(GCDAsyncSocket *)socket clientID:(NSString *)clientID
{
    
    for (LxSocketClientModel *client in self.allClientModels) {
        if ([client.clientID isEqualToString:clientID]) {
            if (client.socket &&
                ![[client.socket lx_objcAddress] isEqualToString:[socket lx_objcAddress]]) {/** 预防新连接与旧连接为同一id **/
                [client.socket disconnect];
            }
            client.socket = socket;
            client.connectStatus = LxSocketConnected;
            client.lastTimeStamp = [[NSDate date] timeIntervalSince1970];
            
            if ([self.tempSocketArray containsObject:socket]) {
                [self.tempSocketArray removeObject:socket];
            }
            break;
        }
    }

}
#pragma mark - ********************  MessageSendAbout  ********************
/** 服务端广播 **/
- (void)udp_serverHostSendToClient:(NSString *)clientHost
{
    [self udp_sendMessage:@"服务端IP" msgType:LxSocketSendMessageServerIp toHost:clientHost];
}
/** 获取发送消息基本结构 **/
- (NSMutableDictionary *)UDP_defaultMessageInfo
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[[NSString stringWithFormat:@"%ld",LxSocketInfoSendTime]] = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    NSString *ip = [IPAddressManage getIPAddress:NO];
    if (ip) {
        info[[NSString stringWithFormat:@"%ld",LxSocketInfoIP]] = ip;
    }else
    {
        //        NSLog(@"获取到空ip");
        [[LxLogInterface sharedInstance] logWithStr:@"获取到空IP"];
    }
    return info;
}
/** 获取tcp发送消息基本结构 **/
- (NSMutableDictionary *)tcp_defaultMessageInfo
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[[NSString stringWithFormat:@"%ld",LxSocketInfoSendTime]] = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    
    return info;
}
/** 发送TCP消息 **/
- (void)tcp_sendMessage:(NSString *)msg msgType:(LxSocketSendMessageType)msgType sockets:(NSArray <GCDAsyncSocket *>*)sockets
{
    NSMutableDictionary *msgInfo = [self tcp_defaultMessageInfo];
    [msgInfo setObject:msg forKey:[NSString stringWithFormat:@"%ld",LxSocketInfoMsg]];
    [msgInfo setObject:[LxSocketHelper lx_strWithInfoKey:msgType] forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]];
    NSString *jsonMsg = [msgInfo lx_JsonString];
    
    for (GCDAsyncSocket *client in sockets) {
        if (client) {
            [client writeData:[jsonMsg dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:0
                                 tag:0];
            [client readDataWithTimeout:-1 tag:0];
        }
    }
}

/** 发送udp消息 **/
- (void)udp_sendMessage:(NSString *)msg msgType:(LxSocketSendMessageType)msgType toHost:(NSString *)host
{
    NSMutableDictionary *msgInfo = [self UDP_defaultMessageInfo];
    [msgInfo setObject:msg forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsg]];
    [msgInfo setObject:[LxSocketHelper lx_strWithInfoKey:msgType] forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]];
    NSString *jsonMsg = [msgInfo lx_JsonString];
    [self.udpSocket sendData:[jsonMsg dataUsingEncoding:NSUTF8StringEncoding]
                      toHost:host
                        port:LxSudp_port
                 withTimeout:2
                         tag:0];
}
#pragma mark - ********************  TCP_delegate  ********************
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;
{
    //    NSLog(@"收到新的连接%@ sock =%@",newSocket.localHost,[sock lx_objcAddress]);
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"收到新的连接%@ sock =%@",newSocket.localHost,[sock lx_objcAddress]]];
    [sock readDataWithTimeout:-1 tag:0];
    if (![self.tempSocketArray containsObject:newSocket]) {
            [self.tempSocketArray addObject:newSocket];
    }
    [self tcp_sendMessage:@"请求id"
                  msgType:LxSocketSendMessageClientIdRequest
                  sockets:@[newSocket]];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;
{
    //    NSLog(@"收到新的连接:%@,port = %d sock = %p",host,port,sock);
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"收到新的连接:%@,port = %d sock = %p",host,port,sock]];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"socket:%p 失去连接%@",sock,err.description);
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"socket:%p 失去连接%@",sock,err.description]];
    [self removeSocket:sock];
    if (self.delegate) {
        [self.delegate tcpConnectLost];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [sock readDataWithTimeout:-1 tag:0];
    NSLog(@"发送数据成功:%p",sock);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    for (NSString *tempJsonStr in jsonArray) {
        NSMutableDictionary *msgInfo = [tempJsonStr lx_getDictionary];
        NSInteger msgType = [msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]] integerValue];
        // NSLog(@"tcp接收到%@",tempJsonStr);
        NSString *message = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsg]];
        NSString *fromID = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]];
        switch (msgType) {
            case LxSocketSendMessageNormal:
            {
                if (self.delegate) {
                    NSTimeInterval clientSendTime = [msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoSendTime]] doubleValue];
                    [self.delegate receivedMessage:message
                                            fromID:fromID
                     msgDelay:[[NSDate date] timeIntervalSince1970] - clientSendTime ];
                }
            }
                break;
                case LxSocketSendMessageClientIdReply:
            {
                [self addSocket:sock clientID:fromID];
                 [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"接收到到消息%@ fromid = %@",message,fromID]];
            }
                break;
            case LxSocketSendMessageHeartBeat:
            {
                [self tcp_sendMessage:@"回复心跳"
                              msgType:LxSocketSendMessageHeartReply
                              sockets:@[sock]];
                for (LxSocketClientModel *client in self.allClientModels) {
                    if ([fromID isEqualToString:client.clientID]) {
                        client.lastTimeStamp = [[NSDate date] timeIntervalSince1970];
                        if (client.connectStatus != LxSocketConnected) {
//                            NSLog(@"sock%@   id = %@由未连接转为连接",sock,fromID);
                            [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"sock%@   id = %@由未连接转为连接",sock,fromID]];
                        }
                        client.connectStatus = LxSocketConnected;
                    }
                }
//                if (self.delegate) {
//                    [self.delegate receiveHeartBeat:message fromID:fromID];
//                }
            }
                break;
            default:
                break;
        }
    }
    [sock readDataWithTimeout:-1 tag:0];
}

#pragma mark - ********************  UDP_delegate  ********************
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    for (NSString *tempJsonStr in jsonArray) {
        NSMutableDictionary *msgInfo = [tempJsonStr lx_getDictionary];
        NSInteger msgType = [msgInfo[@(LxSocketInfoMsgType)] integerValue];
        for (NSString *key in msgInfo) {
            NSString *value = msgInfo[key];
            [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"接收到的消息---%@:%@：",[LxSocketHelper lx_socketKeyMsgWithType:[key integerValue]],value]];
        }
        NSString *fromID = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]];
        switch (msgType) {
            case LxSocketSendMessageIpRequest:
            {
                NSString *ip = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoIP]];
                if (ip && [self checkExistClientID:fromID]) {
                    [self udp_serverHostSendToClient:ip];
                }
            }
                break;
            default:
                break;
        }
    }
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error{
    //    NSLog(@"UDP断开连接");
    [[LxLogInterface sharedInstance] logWithStr:@"UDP断开连接"];
    /** 发送广播不成功时此处会调用 **/
    [self reTryHostBind];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
    //    NSLog(@"UDP发送的消息");
//    [[LxLogInterface sharedInstance] logWithStr:@"UDP发送的消息"];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address{
    //    NSLog(@"UDP已经连接");
    [[LxLogInterface sharedInstance] logWithStr:@"UDP已经连接"];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error{
    //    NSLog(@"UDP断开连接");
    [[LxLogInterface sharedInstance] logWithStr:@"UDP断开连接close"];
    [self reTryHostBind];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error{
    //    NSLog(@"没有发送数据");
    [[LxLogInterface sharedInstance] logWithStr:@"没有发送数据"];
     [self reTryHostBind];
}
@end
