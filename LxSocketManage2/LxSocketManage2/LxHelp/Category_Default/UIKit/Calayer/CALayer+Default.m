//
//  CALayer+Default.m
//  SmartPiano
//
//  Created by 李翔 on 2017/5/9.
//  Copyright © 2017年 XiYun. All rights reserved.
//

#import "CALayer+Default.h"
#import "UIImage+Default.h"
#import <objc/runtime.h>
@implementation CALayer (Default)
static char zoomScaleStr;
#pragma mark - SetMethod
- (void)lx_setImage:(UIImage *)image
{
    self.contents = (id)[image CGImage];
    CGRect rect = self.frame;
    rect.size = image.size;
    self.frame = rect;
}
- (void)setZoomScale:(NSString *)zoomScale
{
    objc_setAssociatedObject(self, &zoomScaleStr, zoomScale, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
#pragma mark - GetMethod
- (NSString *)lx_address
{
    return [NSString stringWithFormat:@"%p",self];
}
- (NSString *)zoomScale
{
    NSString *scale = objc_getAssociatedObject(self, &zoomScaleStr);
    
    return [scale floatValue] > 0 ? scale :@"1";
}
#pragma mark - CallFunction

- (UIImage *)lx_setImageWithImageName:(NSString *)imageName
{
    UIImage *image = [UIImage lx_imageFromBundleWithName:imageName];
    if (image) {
        [self lx_setImage:image];
    }
    return image;
}


- (UIImage *)lx_snapshotImage {
    @autoreleasepool {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [self renderInContext:context];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return image;
    }
}

- (void)lx_zoomScaleReset
{
    CGFloat scale = 1 / [self.zoomScale floatValue];
    [self lx_zoomScale:scale
scalePriScaleDirection:LxCalayerScalePriCenter];
}
/**
 *@description 获取图片,默认居中
 *@param edge截取图片画板内容个方向的增量
 **/
- (UIImage *)lx_snapshotImageWithOffsetEdge:(UIEdgeInsets)edge
{
    @autoreleasepool {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.bounds.size.width + (edge.left + edge.right), self.bounds.size.height + (edge.top + edge.right)), self.opaque, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(context, edge.left, edge.top);
        [self renderInContext:context];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    }
}

- (void)lx_pauseAnimation
{
    CFTimeInterval pausedTime = [self convertTime:CACurrentMediaTime() fromLayer:nil];
    self.speed = 0.0;
    self.timeOffset = pausedTime;
}

- (void)lx_resumeAnimation
{
    CFTimeInterval pausedTime = [self timeOffset];
    self.speed = 1.0;
    self.timeOffset = 0.0;
    self.beginTime = 0.0;
    CFTimeInterval timeSincePause = [self convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    self.beginTime = timeSincePause;
}
/******************************************************ScaleAbout***************************************************************/
/**
 *@description 设置layer比例缩放
 *@param
 **/
- (void)lx_zoomScale:(CGFloat)scale
scalePriScaleDirection:(LxCalayerScalePriDirection)priDirection
{
    CGFloat newWidth = CGRectGetWidth(self.frame) * (1 / [self.zoomScale floatValue]) * scale;
    CGFloat newHeight = CGRectGetHeight(self.frame) * (1 / [self.zoomScale floatValue]) * scale;
    self.zoomScale = [NSString stringWithFormat:@"%f",scale];
    switch (priDirection) {
        case LxCalayerScalePriCenter:
        {
           self.frame = CGRectMake(CGRectGetMidX(self.frame) - newWidth/2.f,
                                   CGRectGetMidY(self.frame) - newHeight/2.f,
                                   newWidth,
                                   newHeight);
        }
            break;
        case LxCalayerScalePriTop:
        {
            self.frame = CGRectMake(CGRectGetMidX(self.frame) - newWidth/2.f,
                                    CGRectGetMinY(self.frame),
                                    newWidth,
                                    newHeight);
        }
            break;
            case LxCalayerScalePriLeft:
        {
            self.frame = CGRectMake(CGRectGetMinX(self.frame),
                                    CGRectGetMinY(self.frame),
                                    newWidth,
                                    newHeight);
        }
            break;
            case LxCalayerScalePriRight:
        {
            self.frame = CGRectMake(CGRectGetMaxX(self.frame) - newWidth,
                                    CGRectGetMidY(self.frame) - newHeight/2.f,
                                    newWidth,
                                    newHeight);
        }
            break;
            case LxCalayerScalePriBottom:
        {
            self.frame = CGRectMake(CGRectGetMidX(self.frame) - newWidth/2.f,
                                    CGRectGetMaxY(self.frame) - newHeight,
                                    newWidth,
                                    newHeight);
        }
            break;

        default:
            break;
    }
}
@end
