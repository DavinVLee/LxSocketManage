//
//  LxSocketManage.h
//  LxSocketManage
//
//  Created by 李翔 on 16/11/1.
//  Copyright © 2016年 李翔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LxSocketConfig.h"
@protocol LxSocketManageDelegate<NSObject>

@optional
- (void)didReceiveMsg:(NSString *)msg;
@end


@interface LxSocketManage : NSObject
/**
 * 本机类型
 */
@property (assign, nonatomic) SocketType type;
/**
 * 连接状态
 */
@property (assign, nonatomic) SocketStatus connectStatus;
/**
 * 获取信息后回调方法
 */
@property (weak, nonatomic) id<LxSocketManageDelegate>delegate;
/**
 * 单例获取
 */
+ (instancetype)sharedInstance;
/**
 * 建立连接
 */
- (BOOL)createConnectWithHost:(NSString *)host;
/**
 * 发送消息
 */
- (void)sendMessage:(NSString *)msg type:(SocketSendMsgType )type;
@end
