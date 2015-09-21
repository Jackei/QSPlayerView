//
//  QSSlider.m
//  QSVideoPlayer
//
//  Created by qizhijian on 15/9/21.
//  Copyright © 2015年 qizhijian. All rights reserved.
//

#import "UISlider+Middle.h"
#import <objc/runtime.h>

#define POINT_OFFSET (2)

static const char * MiddleView;

@implementation UISlider(Middle)

- (void)setMiddleValue:(CGFloat)middleValue
{
    UIProgressView *view = objc_getAssociatedObject(self, &MiddleView);
    if (view)
    {
        view.progress = middleValue;
    }
    else
    {
        CGRect rect = self.bounds;
        
        rect.origin.x += POINT_OFFSET;
        rect.origin.y = rect.size.height/2-0.5;
        rect.size.width -= POINT_OFFSET*2;
        
        UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:rect];
        progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        progressView.userInteractionEnabled = NO;
    
        [self addSubview:progressView];
        [self sendSubviewToBack:progressView];
    
        progressView.progressTintColor = [UIColor orangeColor];
        progressView.trackTintColor = [UIColor blackColor];
        self.maximumTrackTintColor = [UIColor clearColor];
        
        progressView.progress = middleValue;
        
        objc_setAssociatedObject(self, &MiddleView, progressView, OBJC_ASSOCIATION_RETAIN);
    }
}

@end
