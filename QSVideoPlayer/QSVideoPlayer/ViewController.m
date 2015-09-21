//
//  ViewController.m
//  QSVideoPlayer
//
//  Created by qizhijian on 15/9/18.
//  Copyright © 2015年 qizhijian. All rights reserved.
//

#import "ViewController.h"
#import "QSPlayerViewController.h"
#import "AFHTTPClient.h"
#import "AFJSONRequestOperation.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
//    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mp4"];
//    QSPlayerViewController *playerVC = [[QSPlayerViewController alloc] initWithLocalMediaURL:url];
//    playerVC.mediaTitle = @"老男孩";
//    [self presentViewController:playerVC animated:YES completion:nil];
    
    NSURL *url = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear1/prog_index.m3u8"];
    QSPlayerViewController *vc = [[QSPlayerViewController alloc] initWithHTTPLiveStreamingMediaURL:url];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
