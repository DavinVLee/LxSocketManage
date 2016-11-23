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
/**
 * 串行队列
 */
@property (strong, nonatomic) dispatch_queue_t msgSendQueue;
/**
 * 心跳定时器
 */
@property (strong, nonatomic) NSTimer *beatTimer;
/**
 * 重连定时器
 */
@property (strong, nonatomic) NSTimer *reconnectTimer;

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

- (instancetype)init

{
    if (self == [super init]) {
        _msgSendQueue = dispatch_queue_create("msgSendQueue", NULL);
    }
    return self;
}

- (NSMutableArray *)socketModelArray
{
    if (!_socketModelArray) {
        _socketModelArray = [NSMutableArray array];
    }
    return _socketModelArray;
}


- (NSString *)dictionnaryToJsonStringWithDic:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *stringData = [NSJSONSerialization dataWithJSONObject:dic
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    if (error) {
        NSLog(@"文本打包错误%@",[error description]);
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    //字典对象用系统json序列化之后的data，转UTF-8后的jsonstring里面包含有"\n"以及" ",需要替换掉
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@" " withString:@""];
    jsonString = [jsonString stringByAppendingString:@"\r\n"];
    return jsonString;
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
    if (initSuccess) {
        self.connectStatus = SocketConnetEd;
    }else
    {
        self.connectStatus = SocketClosed;
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
    
    dispatch_async(self.msgSendQueue, ^{
        NSMutableDictionary *msgInfo = [NSMutableDictionary dictionaryWithObject:msg forKey:@"message"];
        [msgInfo setObject:@(type) forKey:@"tag"];
        
        NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
        
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        
        if (self.type == SocketServer) {
            for (LxSocketModel *model in self.socketModelArray) {
                [model.socket writeData:jsonData withTimeout:1 tag:0];
                [model.socket readDataWithTimeout:-1 tag:0];
            }
        }else
        {
            [self.socket writeData:jsonData withTimeout:1 tag:0];
            [self.socket readDataWithTimeout:-1 tag:0];
        }
        
    });
    
}

#pragma mark - SocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    [self.socket readDataWithTimeout:-1 tag:0];
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //TODO:由于出现粘包问题，此处以"\r\n"为分割出字符串数组，依次处理
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    for (NSString *tempStr in jsonArray) {
        if (tempStr.length < 1) {
            continue;
        }
        NSData *jsonData = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error = nil;
        NSDictionary *info = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            NSLog(@"收到数据解析错误%@",[error description]);
        }
        NSString *msgStr = info[@"message"];
        NSLog(@"收到----%@",msgStr);
        NSInteger type = [info[@"tag"] integerValue];
        switch (type) {
            case SocketSendMsgNormal:
            {
                if (msgStr.length > 0) {
                    if (self.type == SocketServer) {
                        for (LxSocketModel *model in self.socketModelArray) {
                            if (model.socket != sock) {
                                [model.socket writeData:data withTimeout:-1 tag:0];
                            }else
                            {
//                                NSDictionary *callBackInfo = @{@"message" : @"成功收到信息",
//                                                               @"tag"     : @(SocketSendMsgReceiveCallBack)};
//                                NSString *callBackJsonStr = [self dictionnaryToJsonStringWithDic:callBackInfo];
//                                NSData *callBackData = [callBackJsonStr dataUsingEncoding:NSUTF8StringEncoding];
//                                [model.socket writeData:callBackData withTimeout:-1 tag:0];
                            }
                        }
                    }else
                    {
//                        NSDictionary *callBackInfo = @{@"message" : @"成功收到信息",
//                                                       @"tag"     : @(SocketSendMsgReceiveCallBack)};
//                        NSString *callBackJsonStr = [self dictionnaryToJsonStringWithDic:callBackInfo];
//                        NSData *callBackData = [callBackJsonStr dataUsingEncoding:NSUTF8StringEncoding];
//                        [self.socket writeData:callBackData withTimeout:-1 tag:0];
                    }
                    if ([_delegate respondsToSelector:@selector(didReceiveMsg:)]){
                        [_delegate didReceiveMsg:msgStr];
                    }
                    
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
    
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    self.connectStatus = SocketConnetEd;
    NSLog(@"服务端--新的连接");
    LxSocketModel *model = [[LxSocketModel alloc] init];
    model.socket = newSocket;
    model.ipAddress = newSocket.connectedHost;//客户端Ip
    [sock readDataWithTimeout:-1 tag:0];
    [newSocket readDataWithTimeout:-1 tag:0];
    
    
    NSInteger index = -1;
    
    for (int i = 0; i < self.socketModelArray.count; i ++) {
        LxSocketModel *localModel = self.socketModelArray[i];
        if ([localModel.ipAddress isEqualToString:model.ipAddress]) {
            index = i;
        }
    }
    if (index >= 0) {
        [self.socketModelArray replaceObjectAtIndex:index withObject:model];
    }else
    {
        [self.socketModelArray addObject:model];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"客户端--已经连接到%@:%d",host,port);
    self.connectStatus = SocketConnetEd;
    [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"失去连接");
    if (sock == self.socket) {
        self.connectStatus = SocketClosed;
    }else
    {
        if ([sock isKindOfClass:[NSNull class]]  && sock != nil) {
            NSInteger removeIndex = -1;
            for (LxSocketModel *model in self.socketModelArray) {
                if ([model.ipAddress isEqualToString:sock.connectedHost]) {
                    removeIndex = [self.socketModelArray indexOfObject:model];
                }
            }
            if (removeIndex >= 0) {
                [self.socketModelArray removeObjectAtIndex:removeIndex];
            }
        }
    }
    
}

- (void)setConnectStatus:(SocketStatus)connectStatus
{
    _connectStatus = connectStatus;
    switch (connectStatus) {
        case SocketConnetEd:
        {
            [self.reconnectTimer invalidate];
            self.reconnectTimer = nil;
            if (!_beatTimer && self.type == SocketClient) {
                _beatTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                              target:self
                                                            selector:@selector(sendBeat)
                                                            userInfo:nil repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:_beatTimer forMode:NSRunLoopCommonModes];
            }
        }
            break;
        case SocketConneting:
        {
            
        }
            break;
        case SocketClosed:
        {
            if (!_reconnectTimer) {
                [_beatTimer invalidate];
                _beatTimer = nil;
                _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                   target:self selector:@selector(reConnectSocket)
                                                                 userInfo:nil
                                                                  repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:self.reconnectTimer forMode:NSRunLoopCommonModes];
            }
            
        }
            break;
        default:
            break;
    }
}

#pragma mark - FUNCTION
- (void)reConnectSocket
{
    NSError *error = nil;
    if (self.type == SocketServer && !self.socket.isConnected && self.connectStatus == SocketClosed) {
        if ([self.socket acceptOnPort:LxSocketPort error:&error]) {
            self.connectStatus = SocketConnetEd;
            [self.reconnectTimer invalidate];
            self.reconnectTimer = nil;
        }
    }else if(self.type == SocketClient && !self.socket.isConnected && self.connectStatus == SocketClosed)
    {
        if ([self.socket connectToHost:LxSocketHost onPort:LxSocketPort error:&error]) {
            self.connectStatus = SocketConnetEd;
            [self.reconnectTimer invalidate];
            self.reconnectTimer = nil;
        }
    }
}

- (void)sendBeat
{
    [self sendMessage:@"心跳" type:SocketSendMsgBeatMsg];
}

- (void)msgReceiveSuccessSend
{
    
}

@end
