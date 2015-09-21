//
//  QSPlayerView.m
//  QSVideoPlayer
//
//  Created by qizhijian on 15/9/18.
//  Copyright © 2015年 qizhijian. All rights reserved.
//

#import "QSPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@implementation QSPlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayer *)player
{
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player
{
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

- (void)dealloc
{
    self.player = nil;
}

@end
