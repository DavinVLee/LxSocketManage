//
//  LxLogInterface.m
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/21.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import "LxLogInterface.h"

@implementation LxLogInterface
 + (LxLogInterface *)sharedInstance
{
    static LxLogInterface *logInstance = nil;
    static dispatch_once_t instanceDispatch;
    dispatch_once(&instanceDispatch, ^{
        logInstance = [[LxLogInterface alloc] init];
    });
    return logInstance;
}

- (void)logWithStr:(NSString *)str
{
    if (_delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate logWithString:str];
            NSLog(@"%@", str);
        });

    }
}
@end
