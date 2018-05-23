//
//  UIColor+Default.m
//  SmartPiano
//
//  Created by 李翔 on 2017/5/9.
//  Copyright © 2017年 XiYun. All rights reserved.
//

#import "UIColor+Default.h"

@implementation UIColor (Default)

#pragma mark - GetMethod
+ (UIColor *)lx_colorWithHexString: (NSString *)color
{
    NSString *cString = [[color stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    // String should be 6 or 8 characters
    if ([cString length] < 6) {
        NSLog(@"！！！传入的十六进制参数不是一个色值");
        return [UIColor clearColor];
    }
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"])
        cString = [cString substringFromIndex:2];
    if ([cString hasPrefix:@"#"])
        cString = [cString substringFromIndex:1];
    if ([cString length] != 6)
    {
        NSLog(@"！！！传入的十六进制参数不是一个色值");
        return [UIColor clearColor];
    }
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    
    //r
    NSString *rString = [cString substringWithRange:range];
    
    //g
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    //b
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:1.0f];
}

+ (UIColor *)lx_DefaultGrownColor
{
    return [UIColor colorWithRed:175.f/255.f green:133.f/255.f blue:110.f/255.f alpha:1];
}

+ (UIColor *)lx_DefaultBlueColor
{
    return lx_UIColorFrom_Rgb(0, 141, 206);
}

/**
 *@description 获取暗蓝色
 **/
+ (UIColor *)lx_DefaultDarkBlueColor
{
    return lx_UIColorFrom_Rgb(83, 126, 127);
}

+ (UIColor *)lx_randomColor
{
    return [UIColor colorWithRed:(random() % 255)/255.f green:(random() % 255)/255.f blue:(random() % 255)/255.f alpha:1];
}

@end
