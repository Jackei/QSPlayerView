//
//  QSPlayerViewController.h
//  QSVideoPlayer
//
//  Created by qizhijian on 15/9/18.
//  Copyright © 2015年 qizhijian. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QSPlayerViewController : UIViewController

@property (nonatomic,strong) NSString *mediaTitle;

- (instancetype)initWithHTTPLiveStreamingMediaURL:(NSURL *)url;
- (instancetype)initWithLocalMediaURL:(NSURL *)url;

@end
