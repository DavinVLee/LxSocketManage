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
#import "jm.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "DDLogMacros.h"
#import "WeTeacherHelpManage.h"
@interface LxSocketManage ()<GCDAsyncSocketDelegate,
GCDAsyncUdpSocketDelegate>


/**
 * 当前已连接socket容器
 */
@property (strong, nonatomic) NSMutableArray <LxSocketModel *>*socketModelArray;
/**
 * 心跳定时器
 */
@property (strong, nonatomic) NSTimer *beatTimer;
/**
 *心跳包发送未收到的次数，若超过6次，学生退出连接 释放控制
 */
@property (assign, nonatomic) NSInteger beatLostCount;
/**
 * 重连定时器
 */
@property (strong, nonatomic) NSTimer *reconnectTimer;
/**
 * 等待连接时间计时
 */
@property (assign, nonatomic) NSInteger connectingCount;

/*************************UDP******************************/

/**
 * 存放客户端通过广播获取的所有IP地址
 */
@property (strong, nonatomic) NSMutableArray *notConnectServerIPArray;
/**
 * 客户端wifi变更提示框
 */
@property (assign, nonatomic) BOOL alertShowed;

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


- (NSString *)dictionnaryToJsonStringWithDic:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *stringData = [NSJSONSerialization dataWithJSONObject:dic
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    if (error) {
        debugLog(@"文本打包错误%@",[error description]);
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    //字典对象用系统json序列化之后的data，转UTF-8后的jsonstring里面包含有"\n"以及" ",需要替换掉
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@" " withString:@""];
    jsonString = [jsonString stringByAppendingString:@"\r\n"];
    return jsonString;
}

- (NSMutableArray *)notConnectServerIPArray
{
    if (!_notConnectServerIPArray) {
        _notConnectServerIPArray = [NSMutableArray array];
    }
    return _notConnectServerIPArray;
}

- (NSString *)getWifiSSID
{
    NSString *ssid = [UIDevice currentDevice].ssidInUsing;
    if ([RCIMMessage sharedRCIMMessage].socketServerSSID.length == 0) {
        [RCIMMessage sharedRCIMMessage].socketServerSSID = ssid;
    }else if (![[RCIMMessage sharedRCIMMessage].socketServerSSID isEqualToString:ssid])
    {
        NSString *alertStr = [NSString stringWithFormat:@"当前wifi改变或失去连接，请手动切换至设置检查"];
        [JMAlertView showAlertViewWithTitle:@"提示"
                                    message:alertStr
                         clickedButtonBlock:^(NSInteger index) {
                             
                             [[RCIMMessage sharedRCIMMessage] socketConnect];
                         } cancelButtonTitle:@"确定"
                          otherButtonTitles:nil];
    }
    if (ssid == nil || [ssid isKindOfClass:[NSNull class]]) {
        ssid = @"";
    }
    return ssid;
}

#pragma mark - CallFunction

- (void)socketErrorReconnect
{
    self.socket.delegate = nil;
    debugLog(@"socket 错误 重新绑定 disconnect********************");
    [self.socket disconnect];
    self.socket = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    for (LxSocketModel *model in self.socketModelArray) {
        [model.socket disconnect];
    }
    [self.socketModelArray removeAllObjects];
    
    [self performSelector:@selector(createConnectWithHost:) withObject:[RCIMMessage sharedRCIMMessage].socketServerIpAdd afterDelay:1];
}

- (BOOL)createConnectWithHost:(NSString *)host
{
    NSString *ipAddress = [IPAddressManage getIPAddress:NO];
    if (_socket == nil) {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                 delegateQueue:dispatch_get_main_queue()];
    }else
    {
        self.socket.delegate = self;
    }
    BOOL initSuccess = NO;
    if ([host isEqualToString:ipAddress]) {
        [RCIMMessage sharedRCIMMessage].socketServerSSID = [UIDevice currentDevice].ssidInUsing;
        initSuccess = [self.socket acceptOnPort:LxSocketPort error:nil];
        self.type = SocketServer;
        if (initSuccess) {
            self.connectStatus = SocketConnetEd;
        }else
        {
            [self.socket disconnect];
            self.socket.delegate  =nil;
            self.socket = nil;
            [self performSelector:@selector(createConnectWithHost:) withObject:host afterDelay:1.0];
            return NO;
        }
    }else
    {
        if (host.length > 0) {
            self.connectStatus = SocketConneting;
        }
        self.type = SocketClient;
    }
    [self UDPSocketConnect];
    return YES;
}


- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    debugLog(@"服务端--发出数据完成");
    [sock readDataWithTimeout:-1 tag:1];
}

- (void)sendMessage:(NSString *)msg type:(SocketSendMsgType )type andForceSend:(BOOL)force
{
    
    NSMutableDictionary *msgInfo = [NSMutableDictionary dictionaryWithObject:msg forKey:@"message"];
    [msgInfo setObject:@(type) forKey:@"tag"];
    
    [msgInfo setObject:([RCIMMessage sharedRCIMMessage].talkRoomID == nil ? @"" : [RCIMMessage sharedRCIMMessage].talkRoomID) forKey:@"targetID"];
    if (self.type == SocketClient) {//老师处时刻发送自身ip和ssid
        [msgInfo setObject:[IPAddressManage getIPAddress:NO] forKey:@"ip"];
        [msgInfo setObject:[mUserDefaults objectForKey:mUserId] forKey:@"id"];
        
    }else
    {
        [msgInfo setObject:[self getWifiSSID] forKey:@"ssid"];
    }
    
    NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    debugLog(@"发出了消息%@",jsonString);
    if (self.type == SocketServer) {
        for (LxSocketModel *model in self.socketModelArray) {
            if ((force || model.isControled) && [[RCIMMessage sharedRCIMMessage].checkInStuIds containsObject:model.userId]) {
                [model.socket writeData:jsonData withTimeout:1 tag:0];
                [model.socket readDataWithTimeout:-1 tag:0];
            }
        }
    }else
    {
        [self.socket writeData:jsonData withTimeout:1 tag:0];
        [self.socket readDataWithTimeout:-1 tag:0];
    }
    
}


- (void)disConnect
{
    _connectStatus = SocketClosed;
    [_notConnectServerIPArray removeAllObjects];
    if (self.type == SocketClient) {
        self.socket.delegate = nil;
        debugLog(@"走了一1遍 disconnect********************");
        [self.socket disconnect];
        [[RCIMMessage sharedRCIMMessage] connectRCIM:[DYSettingTool objectForKey:YDRongYunToken] success:^(NSString *userId) {
            [mUserDefaults setValue:userId forKey:RCIMUserId];
        } error:^(NSInteger status) {
            NSLog(@"status = %ld",(long)status);
        } tokenIncorrect:^(NSString *messsge) {
            NSLog(@"messsge = %@",messsge);
        }];
    }else
    {
        self.socket.delegate = nil;
        [self.socket disconnectAfterWriting];
        [self sendMessage:@"关闭连接" type:SocketSendMsgBeConnectClosed andForceSend:YES];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_reconnectTimer invalidate];
    _reconnectTimer = nil;
    [_beatTimer invalidate];
    _beatTimer = nil;
    [self.socketModelArray removeAllObjects];
    
    _udpSocket.delegate = self;
    NSError *error = nil;
    [_udpSocket beginReceiving:&error];
    if (error != nil) {
        [self UdpSocketErrorReset];
    }
}

#pragma mark - SocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    [self.socket readDataWithTimeout:-1 tag:0];
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //TODO:由于出现粘包问题，此处以"\r\n"为分割出字符串数组，依次处理
    NSArray *jsonArray = [jsonString componentsSeparatedByString:@"\r\n"];
    if (self.notConnectServerIPArray.count > 0) {
        [self.notConnectServerIPArray removeAllObjects];
    }
    for (NSString *tempStr in jsonArray) {
        if (tempStr.length < 1) {
            continue;
        }
        NSData *jsonData = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error = nil;
        NSDictionary *info = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            debugLog(@"收到数据解析错误%@",[error description]);
        }
        NSString *msgStr = info[@"message"];
        debugLog(@"收到----%@",msgStr);
        NSInteger type = [info[@"tag"] integerValue];
        switch (type) {
            case SocketSendMsgNormal:
            {
                if (msgStr.length > 0) {
                    if (self.type == SocketServer) {
                        for (LxSocketModel *model in self.socketModelArray) {
                            if (model.socket != sock) {
                                [model.socket writeData:data withTimeout:-1 tag:0];
                            }
                        }
                    }
                    if ([_delegate respondsToSelector:@selector(didReceiveMsg:)]){
                        [_delegate didReceiveMsg:info];
                    }
                    
                }
            }
                break;
            case SocketSendMsgConnectionCheck:
            {
                [self sendMessage:@"connectSuccess" type:SocketSendMsgConnectSuccessCallBack andForceSend:YES];
            }
                break;
            case SocketSendMsgConnectionCheckCallBack:
            {
                NSLog(@"收到老师确认连接成功");
                self.connectStatus = SocketConnetEd;
                [self.socket readDataWithTimeout:-1 tag:0];
            }
                break;
            case SocketSendMsgConnectSuccessCallBack:
            {debugLog(@"与老师连接成功");
                [self sendMessage:[mUserDefaults objectForKey:mUserId] type:SocketSendMsgCliendIdSet andForceSend:YES];
                [NSObject cancelPreviousPerformRequestsWithTarget:self];
                [self.notConnectServerIPArray removeAllObjects];
                self.connectStatus = SocketConnetEd;
                [self.socket readDataWithTimeout:-1 tag:0];
                [self.reconnectTimer invalidate];
                self.reconnectTimer = nil;
                self.alertShowed = NO;
            }
                break;
            case SocketSendMsgBeConnectClosed:
            {
                [self disConnect];
            }
                break;
            case SocketSendMsgBeatMsg://收到学生心跳记录
            {
                NSLog(@"收到学生心跳");
                [self sendMessage:@"connected" type:SocketSendMsgBeatCallBack andForceSend:YES];
            }
                break;
            case SocketSendMsgBeatCallBack:
            {
                NSLog(@"收到老师心跳的回应");
                if ([msgStr isEqualToString:@"connected"]) {
                    self.beatLostCount = 0;
                }
            }
                break;
            case SocketSendMsgCliendIdSet:
            {
                NSString *clientIp = info[@"ip"];
                for (LxSocketModel *model in self.socketModelArray) {
                    if ([model.ipAddress isEqualToString:clientIp] && [[RCIMMessage sharedRCIMMessage].checkInStuIds containsObject:msgStr]) {
                        NSString *clientId = info[@"id"];
                        model.userId = clientId;
                        model.isControled = YES;
                    }
                }
            }
                break;
            default:
                break;
        }
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    self.connectStatus = SocketConnetEd;
    debugLog(@"服务端--新的连接");
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
            [localModel.socket disconnect];
        }
    }
    
    NSDictionary *msgInfo = @{@"message"   :  @"socket连接成功",
                              @"tag"       :  @(SocketSendMsgConnectSuccessCallBack),
                              @"ssid"      :  [self getWifiSSID]};
    
    NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    [newSocket writeData:jsonData withTimeout:-1 tag:0];
    [newSocket readDataWithTimeout:-1 tag:0];
    if (index >= 0) {
        [self.socketModelArray replaceObjectAtIndex:index withObject:model];
    }else
    {
        [self.socketModelArray addObject:model];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    
}

- (void)setConnectStatus:(SocketStatus)connectStatus
{
    _connectStatus = connectStatus;
    switch (connectStatus) {
        case SocketConnetEd:
        {
            [_notConnectServerIPArray removeAllObjects];
            [_reconnectTimer invalidate];
            _reconnectTimer = nil;
            if (!_beatTimer && _type == SocketClient) {
                _beatTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                              target:self
                                                            selector:@selector(sendBeat)
                                                            userInfo:nil repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:_beatTimer forMode:NSRunLoopCommonModes];
            }else if (_type == SocketServer)
            {
                [RCIMMessage sharedRCIMMessage].socketServerSSID = [UIDevice currentDevice].ssidInUsing;
            }
        }
            break;
        case SocketConneting://表示通过老师验证 并获取到老师IP地址
        {
            NSError *error = nil;
            [_socket disconnect];
            if ([_socket connectToHost:[RCIMMessage sharedRCIMMessage].socketServerIpAdd onPort:LxSocketPort error:&error]) {
                NSLog(@"开始connecttoHost");
                if (error != nil) {
                    [self socketErrorReconnect];
                }else
                {
                    [self sendMessage:@"connectionCheck" type:SocketSendMsgConnectionCheck andForceSend:YES];//发送确认连接消息
                }
            }else
            {
                _connectStatus = SocketClosed;
            }
        }
            break;
        case SocketClosed:
        {
            if (!_reconnectTimer) {
                debugLog(@"走了一2遍 disconnect********************");
                [_socket disconnect];
                self.connectingCount = 2;
                _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                                   target:self selector:@selector(reConnectSocket)
                                                                 userInfo:nil
                                                                  repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:_reconnectTimer forMode:NSRunLoopCommonModes];
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
    //    if ([YDUserInfo sharedYDUserInfo].userType == UserTypeTeacher) {
    //        [_udpSocket enableBroadcast:YES error:nil];
    //        [self sendServerIpAddress];
    //    }else if([YDUserInfo sharedYDUserInfo].userType == UserTypeStudent && ![WeTeacherHelpManage sharedInstance].noWlan){
    //        [_udpSocket enableBroadcast:YES error:nil];
    //        [self sendClientIPandId];
    //    }
    //    if (self.connectingCount <= 0) {
    //        [self.reconnectTimer invalidate];
    //        self.reconnectTimer = nil;
    //    }
    //    self.connectingCount --;
}

- (void)clientSsidCheckWithServerSSID:(NSString *)ssid
{
    if ([RCIMMessage sharedRCIMMessage].socketServerSSID.length < 1) {
        [RCIMMessage sharedRCIMMessage].socketServerSSID = ssid;
        self.connectStatus = SocketClosed;
    }else if (![[RCIMMessage sharedRCIMMessage].socketServerSSID isEqualToString:ssid])
    {
        if (!self.alertShowed) {
            NSString *alertStr = [NSString stringWithFormat:@"当前wifi改变或失去连接，请手动切换至设置检查"];
            self.alertShowed = YES;
            [JMAlertView showAlertViewWithTitle:@"提示" message:alertStr
                             clickedButtonBlock:^(NSInteger index) {
                                 [RCIMMessage sharedRCIMMessage].socketServerSSID = @"";
                                 [RCIMMessage sharedRCIMMessage].selfSocketIpAdd = @"";
                                 [[RCIMMessage sharedRCIMMessage] socketConnect];
                                 self.connectStatus = SocketClosed;
                                 
                             } cancelButtonTitle:@"确定"
                              otherButtonTitles:nil];
            
        }else
        {
            self.connectStatus = SocketClosed;
        }
    }
}

- (void)sendBeat
{
    if (self.beatLostCount > 10) {
        NSLog(@"超过六次心跳包未收到回应，十方控制权");
        [SPHudView showMessageWithCenterView:nil Type:SPHudViewTextRightAndBottom text:@"老师解除控制" duration:2.f];
        self.beatLostCount = 0;
        [self disConnect];
        [YDUserInfo sharedYDUserInfo].beControlByTeacher = NO;
        [YDUserInfo sharedYDUserInfo].inBeTeached = NO;
        [mAppDelegate.rootMapVC resetControlEnable];
    }else
    {
        self.beatLostCount ++;
        [self sendMessage:@"心跳" type:SocketSendMsgBeatMsg andForceSend:YES];
    }
    
}

- (void)wifiSetJumpTarget
{
    NSURL *url = [NSURL URLWithString:@"prefs:root=WIFI"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                [SPHudView showMessageWithCenterView:nil
                                                Type:SPHudViewTextWarning
                                                text:@"跳转错误,请手动切换只设置页面更改wifi设置" duration:1.5];
            }
        }];
    }
}

#pragma mark - Notification
- (void)didEnterForeground
{
    //    if (self.connectStatus != SocketConneting) {
    //        [[RCIMMessage sharedRCIMMessage] socketConnect];
    //    }
}

#pragma mark - ********************UDP***********************
/**
 *在每次UDP广播开始接收或绑定时将UDPreset并在延迟一秒后重新连接
 */
- (void)UdpSocketErrorReset
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self.udpSocket setDelegate:nil];
    [self.udpSocket close];
    self.udpSocket = nil;
    [self performSelector:@selector(UDPSocketConnect) withObject:nil afterDelay:1.0];
}

- (void)UDPSocketConnect
{
    NSError *error = nil;
    if (_udpSocket == nil) {
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        [_udpSocket bindToPort:100 error:&error];
        if (error != nil) {
            debugLog(@"广播绑定错误");
            [self UdpSocketErrorReset];
            return;
        }
    }else
    {
        _udpSocket.delegate = self;
    }
    [_udpSocket beginReceiving:&error];
    if (error != nil) {
        debugLog(@"广播开始接收错误");
        [self UdpSocketErrorReset];
        return;
    }
    [_udpSocket enableBroadcast:YES error:&error];
    if (error != nil) {
        debugLog(@"广播设置可接收广播操作错误");
        [self UdpSocketErrorReset];
        return;
    }
    if ([YDUserInfo sharedYDUserInfo].userType == UserTypeTeacher && ![WeTeacherHelpManage sharedInstance].noWlan) {
        
        //每次第一个服务端广播均为强制广播
        NSTimeInterval timeDelay = 1.0;
        for (int i = 0; i < 3; i ++) {
            [self performSelector:@selector(sendServerIpAddress) withObject:nil afterDelay:timeDelay];
            timeDelay += 1;
        }
    }else if([YDUserInfo sharedYDUserInfo].userType == UserTypeStudent){
        
        NSTimeInterval timeDelay = 0;
        for (int i = 0 ; i < 3; i ++) {
            [self performSelector:@selector(sendClientIPandId) withObject:nil afterDelay:timeDelay];
            timeDelay += 1;
        }
    }
    
}
//老师广播自己的serverIP
- (void)sendServerIpAddress
{
    NSDictionary *msgInfo = @{@"message" : [IPAddressManage getIPAddress:NO],
                              @"tag"     : @(SocketSendMsgNormal),
                              @"ip"      : [IPAddressManage getIPAddress:NO]};
    NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
    NSData   *jsonData   = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    [_udpSocket sendData:jsonData toHost:@"255.255.255.255" port:100 withTimeout:-1 tag:0];
    NSError *error = nil;
    [_udpSocket beginReceiving:&error];
    if (error) {
        debugLog(@"11广播设置可接收广播操作错误");
        [self UdpSocketErrorReset];
    }
    
}
//学生广播自己的clientID和IP
- (void)sendClientIPandId
{
    NSDictionary *msgInfo = @{@"message" : [mUserDefaults objectForKey:mUserId],
                              @"tag"     : @(SocketSendMsgUDPidCheck),
                              @"serverIp": [RCIMMessage sharedRCIMMessage].socketServerIpAdd,
                              @"ip"      : [IPAddressManage getIPAddress:NO]};
    NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    [_udpSocket sendData:jsonData toHost:@"255.255.255.255" port:100 withTimeout:-1 tag:0];
    NSError *error = nil;
    [_udpSocket beginReceiving:&error];
    if (error != nil) {
        debugLog(@"1广播设置可接收广播操作错误");
        [self UdpSocketErrorReset];
    }
}

- (void)UDPSocketConnectCheck
{
    [self.notConnectServerIPArray removeAllObjects];
    
    if (![self.udpSocket isConnected]) {
        [self.udpSocket setDelegate:nil];
        [self.udpSocket close];
        [self UDPSocketConnect];
    }else
    {
        [self.udpSocket beginReceiving:nil];
    }
}

- (void)sendUDPMessage:(NSString *)msg type:(SocketSendMsgType )type withServerHost:(NSString *)host
{
    NSDictionary *msgInfo = @{@"message" : msg,
                              @"tag"     : @(type),
                              @"serverIp": [IPAddressManage getIPAddress:NO],
                              @"ip"      : [IPAddressManage getIPAddress:NO]};
    NSString *jsonString = [self dictionnaryToJsonStringWithDic:msgInfo];
    NSData   *jsonData   = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    [_udpSocket sendData:jsonData toHost:host port:100 withTimeout:-1 tag:0];
    NSError *error = nil;
    [_udpSocket beginReceiving:&error];
    if ( error) {
        [self.udpSocket setDelegate:nil];
        [self.udpSocket close];
        self.udpSocket = nil;
        [self UDPSocketConnect];
        
    }
}

- (void)checkUserIdInMatchTeacher//此处学生UDP发送老师本人ID
{
    if (self.notConnectServerIPArray.count > 0) {
        [self.notConnectServerIPArray removeObjectAtIndex:0];
        [self sendClientIPandId];
    }
}

#pragma mark - delegate
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
    debugLog(@"没有连接%@",[error description]);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
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
            debugLog(@"收到数据解析错误%@",[error description]);
        }
        NSString *msgStr = info[@"message"];
        NSInteger type = [info[@"tag"] integerValue];
        NSString *msgIP = info[@"ip"];
        if ([msgIP isEqualToString:[IPAddressManage getIPAddress:NO]]) {
            return;
        }
        // debugLog(@"收到广播----%@  - type = %ld",msgStr,type);
        switch (type) {
            case SocketSendMsgNormal:
            {
                
                if ([YDUserInfo sharedYDUserInfo].userType == UserTypeStudent &&
                    ! [msgStr isEqualToString:[IPAddressManage getIPAddress:NO]]) {//此处学生收到老师广播的IP ，加入并轮询连接
                    if (self.notConnectServerIPArray.count > 0) {
                        [self.notConnectServerIPArray addObject:msgStr];
                        if (self.connectStatus == SocketConnetEd) {//应对老师端从无网到有网的情况
                            [self performSelector:@selector(checkUserIdInMatchTeacher) withObject:nil afterDelay:1.0];
                        }else
                        {
                            [self checkUserIdInMatchTeacher];
                        }
                        
                    }else
                    {
                        [self.notConnectServerIPArray addObject:msgStr];
                        if (self.connectStatus == SocketConnetEd) {
                            [self performSelector:@selector(checkUserIdInMatchTeacher) withObject:nil afterDelay:1.0];
                        }else
                        {
                            [self checkUserIdInMatchTeacher];
                        }
                        
                    }
                }else if ([msgStr isEqualToString:[RCIMMessage sharedRCIMMessage].socketServerIpAdd] && self.type == SocketClient)
                {
                    [self.notConnectServerIPArray addObject:msgStr];
                    [self checkUserIdInMatchTeacher];
                }
            }
                break;
            case SocketSendMsgUDPidCheckCallBack:
            {
                if ([msgStr integerValue] == 1) {//老师收到学生验证id后给予的回执
                    NSLog(@"收到老师确认id信息");
                    [self.notConnectServerIPArray removeAllObjects];
                    [RCIMMessage sharedRCIMMessage].socketServerIpAdd = info[@"serverIp"];
                    
                    self.socket.delegate = self;
                    self.connectStatus = SocketConneting;
                    // debugLog(@"收到服务端检测验证成功");
                }else if([msgStr integerValue] == 0)
                {
                    // debugLog(@"继续下一个验证");
                    [self checkUserIdInMatchTeacher];
                }else if([msgStr integerValue] == 2) //此时老师为wlan设置，切换至wlan
                {
                    [[WeTeacherHelpManage sharedInstance] setWlanConnect];
                }
            }
                break;
            case SocketSendMsgUDPidCheck:
            {
                if (self.type == SocketServer) {
                    NSString *clientIP = info[@"ip"];
                    if ([WeTeacherHelpManage sharedInstance].noWlan) {
                         debugLog(@"说明老师和学生网络类型不同");
                        [self sendUDPMessage:@"2" type:SocketSendMsgUDPidCheckCallBack withServerHost:clientIP];
                    }
                    else if ([[RCIMMessage sharedRCIMMessage].checkInStuIds containsObject:msgStr]) {//老师收到学生id后 检测是否为点名学生
                        debugLog(@"验证成功并反馈");
                        NSError *error = nil;
                        [self.socket acceptOnPort:LxSocketPort error:&error];
                        //                        if (error != nil) {
                        //                            [self socketErrorReconnect];
                        //                        }else
                        //                        {
                        self.socket.delegate = self;
                        [self sendUDPMessage:@"1" type:SocketSendMsgUDPidCheckCallBack withServerHost:clientIP];
                        //
                        //                        }
                    }else
                    {
                        debugLog(@"验证失败并反馈");
                        [self sendUDPMessage:@"0" type:SocketSendMsgUDPidCheckCallBack withServerHost:clientIP];
                    }
                    
                }
            }
                break;
                
            default:
                break;
        }
        
    }
    
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    debugLog(@"发送消息成功");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    debugLog(@"发送消息失败:%@",[error description]);
    if (self.type == SocketClient) {
        [self checkUserIdInMatchTeacher];
    }
}


@end
