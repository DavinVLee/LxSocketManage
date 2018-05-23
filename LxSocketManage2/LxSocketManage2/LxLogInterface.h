//
//  LxLogInterface.h
//  LxSocketManage2
//
//  Created by DavinLee on 2018/5/21.
//  Copyright © 2018年 DavinLee. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol LxLogInstanceDelegate <NSObject>
@optional
- (void)logWithString:(NSString *)str;

@end

@interface LxLogInterface : NSObject

@property (weak, nonatomic) id <LxLogInstanceDelegate> delegate;

+ (LxLogInterface *)sharedInstance;

- (void)logWithStr:(NSString *)str;

@end
