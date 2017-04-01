//
//  LxSocketModel.h
//  LxSocketManage
//
//  Created by 李翔 on 16/11/1.
//  Copyright © 2016年 李翔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CocoaAsyncSocket.h"
@interface LxSocketModel : NSObject
/**
 * socket
 */
@property (strong, nonatomic) GCDAsyncSocket *socket;
/**
 * ipAddress
 */
@property (strong, nonatomic) NSString *ipAddress;
/**
 * Control
 */
@property (assign, nonatomic) BOOL isControled;
/**
 * userID
 */
@property (copy, nonatomic) NSString *userId;
@end
