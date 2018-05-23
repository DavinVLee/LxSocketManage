//
//  SKTextureAtlas+Default.h
//  SmartPiano
//
//  Created by DavinLee on 2017/12/26.
//  Copyright © 2017年 XiYun. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface SKTextureAtlas (Default)
/**
 *@description 获取对应图集内的所有纹理
 *@param atlasName 图集名称
 *@param prefixName 纹理前缀
 *@param count  纹理数量
 **/
+ (NSArray *)lx_getTexturesWithAtlasName:(NSString *)atlasName
                              prefixName:(NSString *)prefixName
                                   count:(NSInteger)count;
@end
