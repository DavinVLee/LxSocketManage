//
//  IPAddressManage.h
//  iOS-Socket-C-Version-Client
//
//  Created by 李翔 on 16/10/31.
//  Copyright © 2016年 huangyibiao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPAddressManage : NSObject

+ (NSString *)getIPAddress:(BOOL)preferIPv4;
+ (BOOL)isValidatIP:(NSString *)ipAddress;
+ (NSDictionary *)getIPAddresses;

@end
