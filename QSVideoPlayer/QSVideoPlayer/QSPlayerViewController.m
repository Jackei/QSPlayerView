//
//  QSPlayerViewController.m
//  QSVideoPlayer
//
//  Created by qizhijian on 15/9/18.
//  Copyright © 2015年 qizhijian. All rights reserved.
//

#import "QSPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "QSPlayerView.h"
#import "UISlider+Middle.h"

#define OFFSET_TIME   5.0
#define VIEW_ALPHA    1.0

static void * playerItemStatusContext = &playerItemStatusContext;
static void * loadedTimeRanges = &loadedTimeRanges;
static void * playerPlayingContext = &playerPlayingContext;
static void * playbackLikelyToKeepUp = &playbackLikelyToKeepUp;

@interface QSPlayerViewController ()

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityView;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *remainTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet QSPlayerView *playerView;
@property (weak, nonatomic) IBOutlet UIView *footerView;
@property (weak, nonatomic) IBOutlet UILabel *presentLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressView;

@property (nonatomic) CMTime duration;
@property (nonatomic) BOOL   playing;
@property (nonatomic) BOOL   canPlay;

@property (nonatomic,strong) AVPlayerItem *playerItem;
@property (nonatomic,strong) AVPlayer     *player;
@property (nonatomic,strong) NSURL        *mediaURL;
@property (nonatomic,strong) id            timeObserver;

@end

@implementation QSPlayerViewController
{
    UISlider *volumeSlider;
    
    CGFloat sysVolume;
    
    CGFloat brightness;
    
    CGFloat screenWidth;
    CGFloat screenHeight;
    
    CGFloat beginTouchX;
    CGFloat beginTouchY;
    
    CGFloat offsetX;
    CGFloat offsetY;
    
    BOOL firstPlay;
    
    BOOL living;
}

#pragma mark -
#pragma mark initialization

- (instancetype)initWithLocalMediaURL:(NSURL *)url
{
    if (self = [super init])
    {
        self.mediaURL = [self checkURL:url];
        [self createLocalMediaPlayerItem];
        [self.progressView setMiddleValue:1.0f];
    }
    return self;
}

- (instancetype)initWithHTTPLiveStreamingMediaURL:(NSURL *)url
{
    if (self = [super init])
    {
        self.mediaURL = [self checkURL:url];
        [self createHLSPlayerItem];
    }
    return self;
}

- (void)createLocalMediaPlayerItem
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.mediaURL options:nil];
    self.playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
}

- (void)createHLSPlayerItem
{
    self.playerItem = [AVPlayerItem playerItemWithURL:self.mediaURL];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self.activityView startAnimating];
    
    screenWidth = [[UIScreen mainScreen] bounds].size.width;
    screenHeight = [[UIScreen mainScreen] bounds].size.height;
    
    if (screenHeight > screenWidth)
    {
        CGFloat tmp = screenWidth;
        screenWidth = screenHeight;
        screenHeight = tmp;
    }
    
    self.headerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
    self.footerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
    
    [self addObserver:self forKeyPath:@"playing" options:NSKeyValueObservingOptionNew context:playerPlayingContext];
    [self addObserver:self forKeyPath:@"playerItem.status" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:playerItemStatusContext];
    [self addObserver:self forKeyPath:@"playerItem.loadedTimeRanges" options:NSKeyValueObservingOptionNew context:loadedTimeRanges];
    [self addObserver:self forKeyPath:@"playerItem.playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:playbackLikelyToKeepUp];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStalled:) name:AVPlayerItemPlaybackStalledNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [self createPlayer];
}

#pragma mark -
#pragma mark Make UI

- (void)createPlayer
{
    self.titleLabel.text = self.mediaTitle;
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    [self.playerView setPlayer:self.player];
    
    [self.playerView.layer setBackgroundColor:[UIColor blackColor].CGColor];
}

#pragma mark -
#pragma mark UITouch

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    UITouch *oneTouch = [touches anyObject];

    beginTouchX = [oneTouch locationInView:oneTouch.view].x;
    beginTouchY = [oneTouch locationInView:oneTouch.view].y;

    brightness = [UIScreen mainScreen].brightness;
    
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    for (UIView *aView in [volumeView subviews]) {
        if ([aView.class.description isEqualToString:@"MPVolumeSlider"]) {
            volumeSlider = (UISlider *)aView;
            break;
        }
    }

    sysVolume = volumeSlider.value;
    
    if (self.headerView.alpha == 0.0)
    {
        [self showHeaderViewAndBottomView];
    }
    else
    {
        [self hideHeaderViewAndBottomView];
        
        [self cancelPerformSelector:@selector(hideHeaderViewAndBottomView)];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    
    UITouch *oneTouch = [touches anyObject];
    
    offsetX = [oneTouch locationInView:oneTouch.view].x - beginTouchX;
    offsetY = [oneTouch locationInView:oneTouch.view].y - beginTouchY;

    CGFloat delta = -offsetY / screenHeight;
    
    CGFloat touchX = [oneTouch locationInView:oneTouch.view].x;
    
    if (touchX < (1.0/5 * screenWidth) && offsetY != 0)
    {
        [self cancelPerformSelector:@selector(hidePresentLabel)];
        [self showPersentLabel];
        
        if (brightness + delta > 0.0 && brightness + delta < 1.0)
        {
            [[UIScreen mainScreen] setBrightness:brightness + delta];
        }
        
        self.presentLabel.text = [NSString stringWithFormat:@"亮度: %.2f%%", (brightness + delta) * 100];
        
        [self performSelector:@selector(hidePresentLabel) withObject:nil afterDelay:1.0f];
    }
    else if (touchX > (4.0/5 * screenWidth) && offsetY != 0)
    {
        if (sysVolume + delta > 0.0 && sysVolume + delta < 1.0)
        {
            [volumeSlider setValue:sysVolume + delta];
        }
    }
    else if (touchX > (1.0/5 * screenWidth) && touchX < (4.0/5 * screenWidth) && offsetX != 0)
    {
        if (living) return;
        if (self.canPlay)
        {
            if (_playing)
            {
                [self.player pause];
            }
            Float64 totalSeconds = CMTimeGetSeconds(self.duration);
            CGFloat persent = (CMTimeGetSeconds(self.player.currentTime) + offsetX) / totalSeconds;
            [self displayProgress:persent];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    UITouch *oneTouch = [touches anyObject];
    
    CGFloat touchX = [oneTouch previousLocationInView:oneTouch.view].x;
    CGFloat off = touchX-beginTouchX;
    
    if (touchX > (1.0/5 * screenWidth) && touchX < (4.0/5 * screenWidth) && off != 0)
    {
        if (living) return;
        if (self.canPlay)
        {
            if (_playing)
            {
                [self.player pause];
            }
            
            Float64 totalSeconds = CMTimeGetSeconds(self.duration);
            CMTime time = CMTimeMakeWithSeconds(CMTimeGetSeconds(self.player.currentTime)+offsetX>=totalSeconds?totalSeconds:CMTimeGetSeconds(self.player.currentTime)+offsetX, self.duration.timescale);
            [self seekToCMTime:time];
        }
    }
    
    
    if (self.headerView.alpha == 0.0)
    {
        
    }
    else
    {
        [self delayHideHeaderViewAndBottomView];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    if (self.headerView.alpha == 0.0)
    {
        
    } else
    {
        [self delayHideHeaderViewAndBottomView];
    }
}

#pragma mark -
#pragma mark display progress

- (void)displayProgress:(CGFloat)progress
{
    [self cancelPerformSelector:@selector(hidePresentLabel)];
    [self showPersentLabel];
    if (progress <= 0.0) progress = 0;
    if (progress >= 1.0) progress = 1.0;
    self.presentLabel.text = [NSString stringWithFormat:@"进度: %.2f%%", progress * 100];
    [self performSelector:@selector(hidePresentLabel) withObject:nil afterDelay:1.0f];
}

#pragma mark -
#pragma mark set play point

- (void)seekToCMTime:(CMTime)time
{
    if (_playing)
    {
        [self.player pause];
    }
    
    [self.player seekToTime:time completionHandler:^(BOOL finished) {
        if (self.playing && finished)
        {
            [self.player play];
        }
    }];
}

#pragma mark -
#pragma mark Hidden

- (void)hiddenActivityView
{
    [self.activityView stopAnimating];
    self.activityView.hidden = YES;
}

- (void)showHeaderViewAndBottomView
{
    [UIView animateWithDuration:0.5 animations:^{
        [self.headerView setAlpha:VIEW_ALPHA];
        [self.footerView setAlpha:VIEW_ALPHA];
    }];
}

- (void)showPersentLabel
{
    self.presentLabel.hidden = NO;
}

- (void)hidePresentLabel
{
    self.presentLabel.hidden = YES;
}

- (void)delayHideHeaderViewAndBottomView
{
    [self cancelPerformSelector:@selector(hideHeaderViewAndBottomView)];
    [self performSelector:@selector(hideHeaderViewAndBottomView) withObject:nil afterDelay:5.0f];
}

- (void)hideHeaderViewAndBottomView
{
    [UIView animateWithDuration:0.5 animations:^{
        [self.headerView setAlpha:0.0];
        [self.footerView setAlpha:0.0];
    }];
}

#pragma mark -
#pragma mark 准备播放

- (void)readyToPlay
{
    [self delayHideHeaderViewAndBottomView];

    self.canPlay = YES;
    [self.playButton setEnabled:YES];
    [self.nextButton setEnabled:YES];
    [self.progressView setEnabled:YES];
    
    self.duration = self.playerItem.duration;
    
    if (self.duration.flags != kCMTimeFlags_Valid)
    {
        living = YES;
        [self.progressView setEnabled:NO];
    }
    
    self.remainTimeLabel.text = [NSString stringWithFormat:@"-%@", [self timeStringWithCMTime:self.duration]];
    
    __weak typeof(self) weakSelf = self;

    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(3, 30) queue:nil usingBlock:^(CMTime time) {

        weakSelf.currentTimeLabel.text = [weakSelf timeStringWithCMTime:time];

        NSString *text = [weakSelf timeStringWithCMTime:CMTimeSubtract(weakSelf.duration, time)];
        
        weakSelf.remainTimeLabel.text = [NSString stringWithFormat:@"-%@", text];

        weakSelf.progressView.value = CMTimeGetSeconds(time) / CMTimeGetSeconds(weakSelf.duration);
        
    }];
    
    if (!firstPlay)
    {
        firstPlay = YES;
        [self playButtonClick:nil];
    }
    
    [self hiddenActivityView];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (context == playerItemStatusContext)
    {
        if (self.playerItem.status == AVPlayerItemStatusReadyToPlay)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self readyToPlay];
            });
        }
        else if (self.playerItem.status == AVPlayerItemStatusFailed)
        {
            [self hiddenActivityView];
            UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"提示" message:@"视频加载失败" preferredStyle:UIAlertControllerStyleAlert];
            [controller addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:controller animated:YES completion:nil];
        }
        else
        {
            [self performSelector:@selector(backClick:) withObject:nil afterDelay:3.0f];
        }
    }
    else if (context == loadedTimeRanges)
    {
        NSTimeInterval timeInterval = [self availableDuration];
        CMTime duration = self.playerItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);

        [self.progressView setMiddleValue:timeInterval/totalDuration];
    }
    else if (context == playerPlayingContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[change objectForKey:@"new"] intValue] == 1)
            {
                [self.playButton setImage:[UIImage imageNamed:@"pause_nor.png"] forState:UIControlStateNormal];
            }
            else
            {
                
                [self.playButton setImage:[UIImage imageNamed:@"play_nor.png"] forState:UIControlStateNormal];
            }
        });
    }
    else if (context == playbackLikelyToKeepUp)
    {
        BOOL status = [[change objectForKey:@"new"] intValue];
        if (status && self.playing)
        {
            [self hiddenActivityView];
            [self.player play];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark 屏幕方向

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeRight;
}

#pragma mark -
#pragma mark Tools

- (NSURL *)checkURL:(id)objc
{
    if (!objc) return nil;
    return [objc isKindOfClass:[NSURL class]]?objc:[NSURL URLWithString:objc];
}

- (void)cancelPerformSelector:(SEL)selector
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
}

- (NSString *)timeStringWithCMTime:(CMTime)time
{
    if (time.value == 0)
    {
        return @"";
    }
    Float64 seconds = time.value/time.timescale;
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    [formatter setDateFormat:(seconds / 3600 >= 1) ? @"h:mm:ss" : @"mm:ss"];
    
    return [formatter stringFromDate:date];
}

- (NSTimeInterval)availableDuration
{
    NSArray *loadedTimeRanges = [[self.playerView.player currentItem] loadedTimeRanges];
    if (loadedTimeRanges.count == 0) return 0;
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;
    return result;
}

#pragma mark -
#pragma mark Outlet IBAction

- (IBAction)slidingEnded:(id)sender
{
    [self delayHideHeaderViewAndBottomView];
}

- (IBAction)slidingProgress:(UISlider *)slider
{
    [self cancelPerformSelector:@selector(hideHeaderViewAndBottomView)];
    
    Float64 totalSeconds = CMTimeGetSeconds(self.duration);
    
    CMTime time = CMTimeMakeWithSeconds(totalSeconds * slider.value, self.duration.timescale);
    
    [self displayProgress:slider.value];
    [self seekToCMTime:time];
}

- (IBAction)sliderTapGesture:(UITapGestureRecognizer *)sender
{
    if (living) return;
    CGFloat tapX = [sender locationInView:sender.view].x;
    CGFloat sliderWidth = sender.view.bounds.size.width;
    
    Float64 totalSeconds = CMTimeGetSeconds(self.duration); // 总时间
    CMTime dstTime = CMTimeMakeWithSeconds(totalSeconds * (tapX / sliderWidth), self.duration.timescale);
    
    [self displayProgress:(tapX / sliderWidth)];
    [self seekToCMTime:dstTime];
    
    [self delayHideHeaderViewAndBottomView];
}


- (IBAction)nextButtonClick:(id)sender
{
    
}

- (IBAction)backClick:(id)sender
{
    [self.player pause];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)playButtonClick:(id)sender
{
    [self cancelPerformSelector:@selector(hideHeaderViewAndBottomView)];
    
    if (!self.playing)
    {
        [self.player play];
        self.playing = YES;
        [self hiddenActivityView];
    }
    else
    {
        [self.player pause];
        self.playing = NO;
    }
    
    [self delayHideHeaderViewAndBottomView];
}

#pragma mark -
#pragma mark Notification

- (void)playbackStalled:(NSNotification *)notification
{
    self.activityView.hidden = NO;
    [self.activityView startAnimating];
}

- (void)appWillResignActive:(NSNotification *)aNotification
{
    [self.player pause];
    self.playing = NO;
}

- (void)appDidBecomActive:(NSNotification *)aNotification
{
    [self.player play];
    self.playing = YES;
}

- (void)playerItemDidPlayToEnd:(NSNotification *)aNotification
{
    [self.player pause];
    [self.playerItem seekToTime:kCMTimeZero];
    self.playing = NO;
}

#pragma mark -
#pragma mark 析构

- (void)dealloc
{
    [self.player pause];
    
    [self removeObserver:self forKeyPath:@"playerItem.status" context:playerItemStatusContext];
    [self removeObserver:self forKeyPath:@"playing" context:playerPlayingContext];
    [self removeObserver:self forKeyPath:@"playerItem.loadedTimeRanges" context:loadedTimeRanges];
    [self removeObserver:self forKeyPath:@"playerItem.playbackLikelyToKeepUp" context:playbackLikelyToKeepUp];
    
    [self.player removeTimeObserver:self.timeObserver];
    self.timeObserver = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
    
    self.player = nil;
    self.playerItem = nil;
    self.mediaURL = nil;
    self.mediaTitle = nil;
}

@end
