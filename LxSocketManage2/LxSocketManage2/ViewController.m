//
//  ViewController.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/15.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "ViewController.h"
#import "LxSocketServerManage.h"
#import "LxSocketClientManage.h"
#import "LxLogInterface.h"
#import "LxSocketHeader.h"
#import "LxSocketClientModel.h"
#import "LxLogInterface.h"
#import "LxSocketHelper.h"
@interface ViewController () <LxLogInstanceDelegate,
                            LxsocketDelegate>
@property (weak, nonatomic) IBOutlet UITextField *idTextFiled;
@property (weak, nonatomic) IBOutlet UITextField *sendMessageTextFiled;
@property (weak, nonatomic) IBOutlet UITextView *receiveMessageTextView;
@property (weak, nonatomic) IBOutlet UITextView *connectStatusTextView;
@property (weak, nonatomic) IBOutlet UITextView *heartBeatTextView;
@property (weak, nonatomic) IBOutlet UILabel *lostConnectLabel;
@property (weak, nonatomic) IBOutlet UILabel *sendMsgCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *lostDataLabel;
#pragma mark - ********************  连接相关  ********************
/** tcpsocket **/
@property (strong, nonatomic) LxSocketServerManage *socketServerManage;
/** udpsocket **/
@property (strong, nonatomic) LxSocketClientManage *socketClientManage;
/** 上一次消息的数值 **/
@property (assign, nonatomic) NSInteger lastReceiveNumber;
@end

@implementation ViewController
#pragma mark - ********************  GetMethod  ********************
- (LxSocketServerManage *)socketServerManage
{
    if (!_socketServerManage) {
        _socketServerManage = [[LxSocketServerManage alloc] init];
        _socketServerManage.delegate = self;
    }
    return _socketServerManage;
}
- (LxSocketClientManage *)socketClientManage
{
    if (!_socketClientManage) {
        _socketClientManage = [[LxSocketClientManage alloc] init];
        _socketClientManage.delegate = self;
    }
    return _socketClientManage;
}
#pragma mark - ********************  init  ********************

- (void)viewDidLoad {
    [super viewDidLoad];
    [LxLogInterface sharedInstance].delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterForgroundReConnect)
                                                 name:@"kApplicationEnterForeground"
                                               object:nil];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)enterForgroundReConnect
{
    [[LxLogInterface sharedInstance] logWithStr:@"进入前台重新连接"];
    if (_socketServerManage) {
        [self hostAsServerBtnClicked:nil];
    }else
    {
        [self hostAsClientBtnClicked:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - ********************  SocketDelegate  ********************
- (void)receivedMessageInfo:(NSDictionary *)messageInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval clientSendTime = [messageInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoSendTime]] doubleValue];
        NSString *message = messageInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoMsg]];
        NSString *fromID = messageInfo[[LxSocketHelper lx_strWithInfoKey:LxSocketInfoUserID]];
        NSTimeInterval msgDelay = [[NSDate date] timeIntervalSince1970] - clientSendTime;
        if ([message integerValue] - self.lastReceiveNumber == 1) {
            
        }else
        {
            self.lostDataLabel.text = [NSString stringWithFormat:@"%ld",[self.lostConnectLabel.text integerValue] + 1];
        }
        self.lastReceiveNumber = [message integerValue];
        NSMutableString *text = [NSMutableString stringWithString:self.receiveMessageTextView.text];
        [text appendString:@"\n"];
        [text appendFormat:@"%@:",fromID];
        [text appendString:message];
        [text appendString:[NSString stringWithFormat:@"延迟时间%f",msgDelay]];
        self.receiveMessageTextView.text = text;
        [self.receiveMessageTextView scrollRectToVisible:CGRectMake(0, self.receiveMessageTextView.contentSize.height - CGRectGetHeight(self.receiveMessageTextView.frame), CGRectGetWidth(self.receiveMessageTextView.frame), CGRectGetHeight(self.receiveMessageTextView.frame)) animated:YES];
    });
}

- (void)receiveHeartBeat:(NSString *)message fromID:(NSString *)fromID
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableString *text = [NSMutableString stringWithString:self.heartBeatTextView.text];
            [text appendString:@"\n"];
            [text appendFormat:@"%@:",fromID];
            [text appendString:message];
            self.heartBeatTextView.text = text;
            [self.heartBeatTextView scrollRectToVisible:CGRectMake(0, self.heartBeatTextView.contentSize.height - CGRectGetHeight(self.heartBeatTextView.frame), CGRectGetWidth(self.heartBeatTextView.frame), CGRectGetHeight(self.heartBeatTextView.frame)) animated:YES];
        });
    });
   
}
- (void)sentMsgCountOnce
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.sendMsgCountLabel.text = [NSString stringWithFormat:@"%ld",[self.sendMsgCountLabel.text integerValue] + 1];
    });
}
- (void)tcpConnectLost
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.lostConnectLabel.text = [NSString stringWithFormat:@"%ld",[self.lostConnectLabel.text integerValue] + 1];
    });
}
#pragma mark - ********************  LogDelegate  ********************
- (void)logWithString:(NSString *)str
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableString *text = [NSMutableString stringWithString:self.connectStatusTextView.text];
            [text appendString:@"\n"];
            [text appendString:str];
            self.connectStatusTextView.text = text;
            [self.connectStatusTextView scrollRectToVisible:CGRectMake(0, self.connectStatusTextView.contentSize.height - CGRectGetHeight(self.connectStatusTextView.frame), CGRectGetWidth(self.connectStatusTextView.frame), CGRectGetHeight(self.connectStatusTextView.frame)) animated:YES];
        });
    });
}

#pragma mark - ********************  ClickAction  ********************
/** 点击作为服务端 **/
- (IBAction)hostAsServerBtnClicked:(id)sender {
    [self.socketServerManage lx_connectAsServerHostWithAvaliableClientModels:[NSMutableArray arrayWithArray: @[[LxSocketClientModel lx_modelWithClientID:@"0" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"1" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"2" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"3" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"4" clientName:@"xxx"],[LxSocketClientModel lx_modelWithClientID:@"5" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"6" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"7" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"8" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"9" clientName:@"xxx"],
                                                                               [LxSocketClientModel lx_modelWithClientID:@"11" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"12" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"13" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"14" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"15" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"16" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"17" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"18" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"19" clientName:@"xxx"],
                                                                                                               [LxSocketClientModel lx_modelWithClientID:@"21" clientName:@"xxx"],]]];
}
/** 点击作为客户端 **/
- (IBAction)hostAsClientBtnClicked:(id)sender {
    [self.socketClientManage lx_connectAsClientWithUserId:self.idTextFiled.text];
}
- (IBAction)sendMessageBtnClicked:(id)sender {
    
    self.sendMsgCountLabel.text = [NSString stringWithFormat:@"%ld",[self.sendMsgCountLabel.text integerValue] + 1];
     self.sendMessageTextFiled.text = [NSString stringWithFormat:@"%ld",[self.sendMessageTextFiled.text integerValue] + 1];
    if (_socketServerManage) {
        [_socketServerManage lx_tcpSendMessage:self.sendMessageTextFiled.text
                                       msgSync:YES
                                 auxiliaryInfo:nil
                                  specialDesID:nil];
    }else
    {
        [_socketClientManage lx_tcpSendMessage:self.sendMessageTextFiled.text];
    }
}
- (IBAction)clearReceiveMessageBtnClicked:(id)sender {
    self.receiveMessageTextView.text = @"";
    self.heartBeatTextView.text = @"";
    self.connectStatusTextView.text = @"";
    self.lostConnectLabel.text = @"0";
    self.sendMsgCountLabel.text = @"0";
    self.lostDataLabel.text = @"0";
    self.lastReceiveNumber = 0;
}
- (IBAction)autoSendClicked:(id)sender {
    [self clearReceiveMessageBtnClicked:nil];
   NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                     target:self
                                                   selector:@selector(autoSend:)
                                                   userInfo:nil
                                                    repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}
- (void)autoSend:(NSTimer *)timer
{
    if ([self.sendMessageTextFiled.text integerValue] <1000) {
       
        [self sendMessageBtnClicked:nil];
    }else
    {
        [timer invalidate];
    }
}

@end
