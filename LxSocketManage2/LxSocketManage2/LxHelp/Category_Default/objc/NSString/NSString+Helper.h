//
//  NSString+Helper.h
//  svgtest2
//
//  Created by 李翔 on 2017/4/25.
//  Copyright © 2017年 ydkj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (Helper)
/***********************************get************************************///
/**
 *@description 获取数组
 **/
- (NSMutableArray *)lx_getArray;

/**N
 *@description 获取字典
 **/
- (NSMutableDictionary *)lx_getDictionary;


/**
 *@description 获取本地cache目录
 **/
+ (NSString *)lx_cacheFolderPath;
/** 确保没有导致崩溃的字符 **/
- (NSString *)lx_SafeStrWithStr:(NSString *)str;

/***********************************文本************************************///
/**
 *@description 获取字符串的内容大小
 **/
- (CGSize)lx_textSizeWithFont:(UIFont *)font MaxSize:(CGSize)maxSize;



@end
