//
//  SKTextureAtlas+Default.m
//  SmartPiano
//
//  Created by DavinLee on 2017/12/26.
//  Copyright © 2017年 XiYun. All rights reserved.
//

#import "SKTextureAtlas+Default.h"

@implementation SKTextureAtlas (Default)
#pragma mark - GetMethod
/**
 *@description 获取对应图集内的所有纹理
 *@param atlasName 图集名称
 *@param prefixName 纹理前缀
 *@param count  纹理数量
 **/
+ (NSArray *)lx_getTexturesWithAtlasName:(NSString *)atlasName
                              prefixName:(NSString *)prefixName
                                   count:(NSInteger)count
{
    SKTextureAtlas *atlas = [SKTextureAtlas atlasNamed:atlasName];
    NSMutableArray *textures = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++) {
        SKTexture *texture = [atlas textureNamed:[NSString stringWithFormat:@"%@%d",prefixName,i]];
        [textures addObject:texture];
    }
    return [NSArray arrayWithArray:textures];
}

@end
