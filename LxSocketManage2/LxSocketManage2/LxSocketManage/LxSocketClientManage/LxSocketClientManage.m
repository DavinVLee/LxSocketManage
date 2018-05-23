//
//  LxSocketClientManage.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/15.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxSocketClientManage.h"
#import "GCDAsyncSocket.h" // for TCP
#import "GCDAsyncUdpSocket.h" // for UDP
#import "NSObject+Default.h"
#import "LxSocketHelper.h"
#import "LxLogInterface.h"
#import "NSDictionary+Helper.h"
#import "NSString+Helper.h"
#import "IPAddressManage.h"
@interface LxSocketClientManage() <GCDAsyncUdpSocketDelegate,
GCDAsyncSocketDelegate>
/** TCP连接对象 **/
@property (strong, nonatomic, getter = tcpSocket) GCDAsyncSocket *tcpSocket;
/** UDP连接对象 **/
@property (strong, nonatomic, getter = udpSocket) GCDAsyncUdpSocket *udpSocket;
/****************************************************** dispatch ***************************************************************/
/** udp广播队列 **/
@property (strong, nonatomic) dispatch_queue_t udpQueue;
/** tcp连接队列 **/
@property (strong, nonatomic) dispatch_queue_t tcpQueue;
/* ********************  userInfo_about  ******************** */
/** 客户端唯一id **/
@property (strong, nonatomic) NSString *clientId;
/** 服务端唯一ip **/
@property (strong, nonatomic) NSString *serverIP;
/** 上一次收到消息的时间戳（避免冲重复消息导致的逻辑问题） * 1000->ms **/
@property (assign, nonatomic) NSInteger lastMessageTimeStamp;
/****************************************************** ConnectAbout ***************************************************************/
@property (strong, nonatomic) NSTimer *runLoopTime;

@end

@implementation LxSocketClientManage
- (instancetype)init
{
    if (self == [super init]) {
        _tcpQueue = dispatch_queue_create("tcpSocketQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - ********************  GetMethod  ********************
- (GCDAsyncSocket *)tcpSocket
{
    if (!_tcpSocket) {
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                delegateQueue:_tcpQueue
                                                  socketQueue:_tcpQueue];
        _tcpSocket.delegate = self;
    }
    return _tcpSocket;
}
/** udp_get **/
- (GCDAsyncUdpSocket *)udpSocket
{
    if (!_udpSocket) {
        _udpQueue = dispatch_queue_create("udpSocketQueue", DISPATCH_QUEUE_SERIAL);
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithSocketQueue:_udpQueue];
        _udpSocket.delegate = self;
        _udpSocket.delegateQueue = _udpQueue;
    }
    return _udpSocket;
}
#pragma mark - ********************  CallFunction  ********************
/**
 *@description 开始搜寻并连接服务端
 *@param userId 作为客户端唯一标识
 **/
- (void)lx_connectAsClientWithUserId:(NSString *)userId
{
    self.clientId = userId;
    /** 开始连接 **/
    BOOL udpCsuccess =  [self udp_connectBegin];
    if (udpCsuccess) {
        self.runLoopTime = [NSTimer scheduledTimerWithTimeInterval:1
                                                            target:self selector:@selector(udp_ipAddressMessageSend:)
                                                          userInfo:nil
                                                           repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.runLoopTime forMode:NSRunLoopCommonModes];
    }
}
/**
 *@description 向服务端发送消息
 **/
- (void)lx_tcpSendMessage:(NSString *)message
{
    [self tcp_sendMessage:message msgType:LxSocketSendMessageNormal];
}
#pragma mark - ********************  function ********************
- (void)tcp_disconnect
{
    [self stopRunloopTimer];
    /** 提前关闭连接 **/
    if (_tcpSocket) {
        _tcpSocket.delegate = nil;
        [_tcpSocket disconnect];
        _tcpSocket = nil;
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
/** 关闭计时器 **/
- (void)stopRunloopTimer
{
    [self.runLoopTime invalidate];
    self.runLoopTime = nil;
}
/** 客户端发送心跳包 **/
- (void)clientHeartBeatSend
{
    [self tcp_sendMessage:@"心跳包发送" msgType:LxSocketSendMessageHeartBeat];
}
#pragma mark - ********************  ConnectAbout********************
/** 因socket绑定或初始化出问题后的延时重新绑定 **/
- (void)reTryHostBind
{
    [self performSelector:@selector(lx_connectAsClientWithUserId:)
               withObject:self.clientId
               afterDelay:1];
    [[LxLogInterface sharedInstance] logWithStr:@"重新进行一次连接"];
}
/** 开始udp连接 **/
- (BOOL)udp_connectBegin
{
    [self tcp_disconnect];
    [self udp_disconnect];
    NSError *error;
    /** 开启广播 **/
    self.udpSocket.delegate = self;
    [self.udpSocket bindToPort:LxSudp_port error:&error];
    if (error) {NSLog(@"绑定PORT失败%@",error.description); [self reTryHostBind];return NO;}
    [self.udpSocket enableBroadcast:YES error:&error];
    if (error) {NSLog(@"启用广播失败%@",error.description); [self reTryHostBind];return NO;}
    [self.udpSocket beginReceiving:&error];
    if (error) {NSLog(@"开启接收数据:%@",error); [self reTryHostBind];return NO;}
    return error == nil;
}
/** 客户端发送获取ip地址广播 **/
- (void)udp_ipAddressMessageSend:(NSTimer *)timer
{
    [self udp_sendMessage:@"请求ip" msgType:LxSocketSendMessageIpRequest];
    [[LxLogInterface sharedInstance] logWithStr:@"客户端发送一次ip请求"];
}
/** 客户端发送tcp连接请求 **/
- (void)tcp_connectRequest
{
    if (self.serverIP == nil) {
        return;
    }
    [self udp_disconnect];
    
    NSError *error;
    /** 开启服务端 **/
    if (_tcpSocket) {
        _tcpSocket.delegate = self;
    }
    BOOL connectSuccess = [self.tcpSocket connectToHost:self.serverIP
                                                 onPort:LxStcp_port
                                                  error:&error];
    if (error || !connectSuccess) {/*NSLog(@"开启服务端失败%@",error.description);*/[[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"开启tcp连接失败%@",error.description]]; [self performSelector:@selector(tcp_connectRequest) withObject:nil afterDelay:1.5];}
    else
    {
        [self.tcpSocket readDataWithTimeout:-1 tag:0];
    } 
}
/** 开始计时发送心跳包 **/
- (void)startHeartBeatSendCircle
{
    [self stopRunloopTimer];
    self.lastMessageTimeStamp = [[NSDate date] timeIntervalSince1970];
 
    dispatch_async(dispatch_get_main_queue(), ^{
        [self tcp_sendHeartBeatMsg];/** 第一次调用手动 **/
        self.runLoopTime = [NSTimer scheduledTimerWithTimeInterval:LxSheartBeatTimeIntravl
                                                            target:self
                                                          selector:@selector(tcp_sendHeartBeatMsg)
                                                          userInfo:nil
                                                           repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.runLoopTime forMode:NSRunLoopCommonModes];
    });

}
#pragma mark - ********************  MessageSendAbout  ********************
/** 发送心跳包 **/
- (void)tcp_sendHeartBeatMsg
{
    NSTimeInterval timeNow = [[NSDate date] timeIntervalSince1970];
    NSLog(@"客户端心跳包时间差%f",timeNow - self.lastMessageTimeStamp);
    if (timeNow - self.lastMessageTimeStamp > LxSheartBeatTimeIntravl * 2) {
        
        [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"出现客户端心跳包超时%f",timeNow - self.lastMessageTimeStamp]];
        [self reTryHostBind];
    }else
    {
      [self tcp_sendMessage:@"心跳" msgType:LxSocketSendMessageHeartBeat];
    }
}
/** 获取发送消息基本结构 **/
- (NSMutableDictionary *)defaultMessageInfoOfUDP
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[[NSString stringWithFormat:@"%ld",LxSocketInfoUserID]] = self.clientId;
    info[[NSString stringWithFormat:@"%ld",LxSocketInfoSendTime]] = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    NSString *ip = [IPAddressManage getIPAddress:NO];
    if (ip) {
        info[[NSString stringWithFormat:@"%ld",lxSocketInfoIP]] = ip;
    }else
    {
        //        NSLog(@"获取到空ip");
        [[LxLogInterface sharedInstance] logWithStr:@"获取到空IP"];
    }
    return info;
}
/** 发送udp消息 **/
- (void)udp_sendMessage:(NSString *)msg msgType:(LxSocketSendMessageType)msgType
{
    NSMutableDictionary *msgInfo = [self defaultMessageInfoOfUDP];
    [msgInfo setObject:msg forKey:[NSString stringWithFormat:@"%ld",LxSocketInfoMsg]];
    [msgInfo setObject:[NSString stringWithFormat:@"%ld",msgType] forKey:[NSString stringWithFormat:@"%ld",LxSocketInfoMsgType]];
    NSString *jsonMsg = [msgInfo lx_JsonString];
    [self.udpSocket sendData:[jsonMsg dataUsingEncoding:NSUTF8StringEncoding]
                      toHost:@"255.255.255.255"
                        port:LxSudp_port
                 withTimeout:1
                         tag:0];
}
/** 获取tcp发送消息基本结构 **/
- (NSMutableDictionary *)tcp_defaultMessageInfo
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[[NSString stringWithFormat:@"%ld",LxSocketInfoSendTime]] = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    info[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]] = self.clientId;
    return info;
}
/** 发送TCP消息 **/
- (void)tcp_sendMessage:(NSString *)msg msgType:(LxSocketSendMessageType)msgType
{
    NSMutableDictionary *msgInfo = [self tcp_defaultMessageInfo];
    [msgInfo setObject:msg forKey:[NSString stringWithFormat:@"%ld",LxSocketInfoMsg]];
    [msgInfo setObject:[LxSocketHelper lx_strWithInfoKey:msgType] forKey:[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]];
    NSString *jsonMsg = [msgInfo lx_JsonString];
    
    [self.tcpSocket writeData:[jsonMsg dataUsingEncoding:NSUTF8StringEncoding]
                  withTimeout:0
                          tag:0];
    [self.tcpSocket readDataWithTimeout:-1 tag:0];
}
#pragma mark - ********************  TCP_delegate ********************
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    for (NSString *tempJsonStr in jsonArray) {
        NSMutableDictionary *msgInfo = [tempJsonStr lx_getDictionary];
        NSInteger msgType = [msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]] integerValue];
        for (NSString *key in msgInfo) {
            NSString *value = msgInfo[key];
            NSLog(@"接收到的消息中tcp = %@:%@：",[LxSocketHelper lx_socketKeyMsgWithType:[key integerValue]],value);
        }
        NSString *message = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsg]];
        NSString *fromID = msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]];
        self.lastMessageTimeStamp = [[NSDate date] timeIntervalSince1970];
        switch (msgType) {
            case LxSocketSendMessageNormal:
            {
                
                if (self.delegate) {
                    [self.delegate receivedMessage:message
                                            fromID:fromID];
                }
                 [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"接收到到消息%@ fromid = %@",message,fromID]];
            }
                break;
            case LxSocketSendMessageClientIdRequest:
            {
                [self tcp_sendMessage:@"回复id" msgType:LxSocketSendMessageClientIdReply];
                 [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"接收到到消息%@ fromid = %@",message,fromID]];
            }
                break;
                case LxSocketSendMessageHeartReply:
            {
                if (self.delegate) {
                    [self.delegate receiveHeartBeat:message fromID:fromID];
                }
            }
                break;
            default:
                break;
        }
    }
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"发送消息成功 sock = %p",sock);
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    //    NSLog(@"连接到ip:%@",host);
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"已连接ip:%@,port = %hu",host,port]];
    [sock readDataWithTimeout:-1 tag:0];
    [self startHeartBeatSendCircle];
    self.lastMessageTimeStamp = [[NSDate date] timeIntervalSince1970];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    //    NSLog(@"断开连接%p  error %@",sock,err.description);
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"断开连接%p  error %@",sock,err.description]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reTryHostBind];
    });
    if (self.delegate) {
        [self.delegate tcpConnectLost];
    }
}

#pragma mark - ********************  UDP_delegate  ********************
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    for (NSString *tempJsonStr in jsonArray) {
        NSMutableDictionary *msgInfo = [tempJsonStr lx_getDictionary];
        NSInteger msgType = [msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsgType]] integerValue];
        NSLog(@"udp接收到%@",tempJsonStr);
        NSInteger messageSendTimeStamp = [msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoSendTime]] floatValue] * 1000;
        if ([msgInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]] isEqualToString:self.clientId] ||
            msgType != LxSocketSendMessageServerIp ||/** 本机广播消息 **/
            messageSendTimeStamp == self.lastMessageTimeStamp /** 该消息为重复的两次发送，去重 **/
            ) {
            return;
        }
        for (NSString *key in msgInfo) {
            NSString *value = msgInfo[key];
            [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"接收到的消息中%@:%@：",[LxSocketHelper lx_socketKeyMsgWithType:[key integerValue]],value]];
        }
        switch (msgType) {
            case LxSocketSendMessageServerIp:
            {
                self.lastMessageTimeStamp = messageSendTimeStamp;
                NSString *ip = msgInfo[[LxSocketHelper lx_strWithInfoKey:lxSocketInfoIP]];
                if (ip) {
                    [self stopRunloopTimer];
                    self.serverIP = ip;
                    [self tcp_connectRequest];
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
    dispatch_async(dispatch_get_main_queue(), ^{
          [self reTryHostBind];
    });
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
    [[LxLogInterface sharedInstance] logWithStr:@"UDP断开连接"];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error{
    //    NSLog(@"@"数据未发送成功%@",error.description");
    [[LxLogInterface sharedInstance] logWithStr:[NSString stringWithFormat:@"数据未发送成功%@",error.description]];
}
@end