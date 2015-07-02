//
//  SecondViewController.m
//  SampleTabbedApp
//
//  Created by Joseph Radjavitch on 7/1/15.
//  Copyright (c) 2015 BCGS. All rights reserved.
//

#import "SecondViewController.h"
#import <BCOVFW.h>
#import <AdManager/FWSDK.h>

static NSString * const kViewControllerSlotId= @"300x250";

@interface SecondViewController () </*BCOVPlaybackControllerDelegate*/BCOVPlaybackSessionConsumer>

@property (nonatomic, strong) id<BCOVPlaybackController> playerController;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (nonatomic, weak) id<FWContext> adContext;
@property (nonatomic, strong) id<FWAdManager> adManager;
@property (nonatomic, weak) IBOutlet UIView *adSlot;

@property (nonatomic) BOOL videoPlaying;
@property (nonatomic) BOOL adPlaying;
@property (nonatomic) BOOL playerReady;

/* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
@property (nonatomic, strong) NSTimer* reachabilityTimer;   // Timer used to detect when network is viable again
@property (nonatomic, assign) CMTime playbackTime;          // Last know playback time
@property (nonatomic) NSInteger sessionRetryCount;
*/

@end

@implementation SecondViewController

#pragma mark - Lazy Load Objects

- (id<FWAdManager>)adManager {
    // The FWAdManager will be responsible for creating all the ad contexts.
    // We use it in the BCOVFWSessionProviderAdContextPolicy created by
    // the -[ViewController adContextPolicy] block.
    
    if (_adManager == nil) {
        _adManager = newAdManager();
        [_adManager setNetworkId:392024];   //90750];
        [_adManager setServerUrl:@"http://5fb58.v.fwmrm.net/"]; //@"http://demo.v.fwmrm.net"];
    }
    
    return _adManager;
}

- (id<BCOVPlaybackController>)playerController {
    if (_playerController == nil) {
        BCOVPlayerSDKManager *manager = [BCOVPlayerSDKManager sharedManager];
        
        _playerController = [manager createFWPlaybackControllerWithAdContextPolicy:[self adContextPolicy] viewStrategy:[manager defaultControlsViewStrategy]];
        
        //_playerController.delegate = self;
        [_playerController addSessionConsumer:self];
        _playerController.view.frame = self.playerView.bounds;
        _playerController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _playerController.view.translatesAutoresizingMaskIntoConstraints = YES;
    }
    
    return _playerController;
}

#pragma mark - View Lifecycle Methods

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:FW_NOTIFICATION_SLOT_STARTED
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:FW_NOTIFICATION_SLOT_ENDED
                                               object:nil];
    
    /* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
    self.sessionRetryCount = 0;
    */

    [self resetPlayerResources];
    [self loadPlayer];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_playerController && self.videoPlaying) {
        self.playerReady = YES;
        [self.playerController play];
    }
    else if (_playerController && self.adPlaying) {
        self.playerReady = YES;
        [self.playerController resumeAd];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (_playerController && self.videoPlaying) {
        self.playerReady = NO;
        [self.playerController pause];
    }
    else if (_playerController && self.adPlaying) {
        self.playerReady = NO;
        [self.playerController pauseAd];
        [self.playerController pause];
    }
}

#pragma mark - Player Methods

- (void)loadPlayer
{
    // Make sure the content view won't cover the any subviews (ad view) in ad container view.
    //[self.playerView addSubview:self.playerController.view];
    [self.playerView insertSubview:self.playerController.view atIndex:0];
    [self loadVideo];
}

- (void)loadVideo
{
    NSURL* url = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"];
    BCOVVideo* newVideo = [[BCOVVideo alloc] initWithSource:[[BCOVSource alloc] initWithURL:url
                                                                             deliveryMethod:@"HLS"
                                                                                 properties:nil]
                                                  cuePoints:nil
                                                 properties:nil];
    
    [self.playerController setVideos:@[newVideo]];
    [self.playerController play];
}

- (BCOVFWSessionProviderAdContextPolicy)adContextPolicy
{
    SecondViewController * __weak weakSelf = self;
    
    return [^ id<FWContext>(BCOVVideo *video, BCOVSource *source, NSTimeInterval videoDuration) {
        
        SecondViewController *strongSelf = weakSelf;
        
        // This block will get called before every session is delivered. The source,
        // video, and videoDuration are provided in case you need to use them to
        // customize the these settings.
        // The values below are specific to this sample app, and should be changed
        // appropriately. For information on what values need to be provided,
        // please refer to your Freewheel documentation or contact your Freewheel
        // account executive. Basic information is provided below.
        id<FWContext> adContext = [strongSelf.adManager newContext];
        
        // These are player/app specific values.
        [adContext setPlayerProfile:@"392024:watchable_ios_test"/*@"90750:3pqa_ios"*/ defaultTemporalSlotProfile:nil defaultVideoPlayerSlotProfile:nil defaultSiteSectionSlotProfile:nil];
        //[adContext setSiteSectionId:@"brightcove_ios" idType:FW_ID_TYPE_CUSTOM pageViewRandom:0 networkId:0 fallbackId:0];
        
        // This is an asset specific value.
        //[adContext setVideoAssetId:@"brightcove_demo_video" idType:FW_ID_TYPE_CUSTOM duration:videoDuration durationType:FW_VIDEO_ASSET_DURATION_TYPE_EXACT location:nil autoPlayType:true videoPlayRandom:0 networkId:0 fallbackId:0];
        
        // This is the view where the ads will be rendered.
        [adContext setVideoDisplayBase:strongSelf.playerView];
        
        // These are required to use Freewheel's OOTB ad controls.
        [adContext setParameter:FW_PARAMETER_USE_CONTROL_PANEL withValue:@"YES" forLevel:FW_PARAMETER_LEVEL_GLOBAL];
        [adContext setParameter:FW_PARAMETER_CLICK_DETECTION withValue:@"NO" forLevel:FW_PARAMETER_LEVEL_GLOBAL];
        
        // This registers a companion view slot with size 300x250. If you don't
        // need companion ads, this can be removed.
        [adContext addSiteSectionNonTemporalSlot:kViewControllerSlotId adUnit:nil width:300 height:250 slotProfile:nil acceptCompanion:YES initialAdOption:FW_SLOT_OPTION_INITIAL_AD_STAND_ALONE acceptPrimaryContentType:nil acceptContentType:nil compatibleDimensions:nil];
        
        // We save the adContext to the class so that we can access outside the
        // block. In this case, we will need to retrieve the companion ad slot.
        strongSelf.adContext = adContext;
        
        return adContext;
        
    } copy];
}

#pragma mark - BCOVPlaybackSessionConsumer

- (void)playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
//    NSLog(@"PlaybackSession Video Info: %@", session.video.sources);
    if (lifecycleEvent)
    {
        NSLog(@"********** Lifecycle Event Type: %@ **********", lifecycleEvent.eventType);
//        NSLog(@"Lifecycle Event Properties: %@", lifecycleEvent.properties);
        
        if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventReady]) {
            self.playerReady = YES;
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPlay]) {
            if (self.playerReady) {
                // Only update the event on a transition and ingnore consecutive events of the same type
                if (!self.videoPlaying) {
                    NSLog(@"This is where you would send the play event to analytics");
                    self.videoPlaying = YES;
                }
            }
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPause]) {
            if (self.playerReady) {
                // Only update the event on a transition and ingnore consecutive events of the same type
                if (self.videoPlaying) {
                    NSLog(@"This is where you would send the pause event to analytics");
                    self.videoPlaying = NO;
                }
            }
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventEnd]) {
            self.videoPlaying = NO;
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventTerminate]) {
            self.videoPlaying = NO;
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventFail]) {
            self.videoPlaying = NO;
        }
        /* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventResumeComplete]) {
            self.sessionRetryCount = 0;
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventFailedToPlayToEndTime]) {
            [self.controls showErrorSlate:kVideoFailedToFinish];
            NSLog(@"ViewController Debug - Lifecycle Event: %@", lifecycleEvent.properties);
            [self retrySession];
        }
        else if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventResumeFail]) {
            NSLog(@"ViewController Debug - Lifecycle Resume Failed Event: %@", lifecycleEvent.properties);
            self.sessionRetryCount++;
            [self retrySession];
        }
        */
    }
}

-(void)didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    @try {
        /* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
        self.playbackTime = kCMTimeZero;
        */
    }
    @catch (id anException) {
        //Error removing the observers, they've already been removed or do not exist.
    }
    
    NSLog(@"ViewController Debug - Advanced to new session.");
}

- (void)playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress;
{
    /* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
    self.playbackTime = CMTimeMake(progress, 1);
     */
}

#pragma mark - Network 

/* AVPlayerFailedToPlayToEnd fixes when upgrading to 4.3.5
 
-(void)handlePlayerFailed:(NSNotification*)note{
    // Schedule timer to check network connection
    NSLog(@"AVPlayer Current Item Failed To Play To End Time Fired");
    
    if (self.reachabilityTimer == nil && self.self.currentPlaybackSession != nil) {
        self.reachabilityTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                  target:self
                                                                selector:@selector(isNetworkAvailable)
                                                                userInfo:nil
                                                                 repeats:YES];
    }
}

- (void)retrySession
{
    if (self.sessionRetryCount <= maxSessionRetries) {
        [self handlePlayerFailed:nil];
    }
    else {
        NSLog(@"The playback session has repeatedly failed to restart. Please try again later.");
    }
}

-(void)isNetworkAvailable
{
    // Use any URL you like www.tvnz.co.nz
    NSURL *scriptUrl = [NSURL URLWithString:@"http://www.google.com"];
    NSData *data = [NSData dataWithContentsOfURL:scriptUrl];
    
    if (!data){
        NSLog(@"-> no connection!\n");
    }
    else{
        NSLog(@"-> connection established!\n");
        [self.controls hideErrorSlate];
        [self.reachabilityTimer invalidate];
        self.reachabilityTimer = nil;
        
        // Restart video
        [self.playerController resumeVideoAtTime:self.playbackTime withAutoPlay:YES];
    }
}

*/

#pragma mark - Memory

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Notifications

- (void) receiveNotification:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:FW_NOTIFICATION_SLOT_STARTED]) {
        NSLog(@"********** FW_NOTIFICATION_SLOT_STARTED **********");
        if (self.playerReady) {
            self.adPlaying = YES;
        }
    }
    else if ([[notification name] isEqualToString:FW_NOTIFICATION_SLOT_ENDED]) {
        NSLog(@"********** FW_NOTIFICATION_SLOT_ENDED **********");
        if (self.playerReady) {
            self.adPlaying = NO;
        }
    }
}

#pragma mark - IBAction

- (IBAction)newVideoTapped:(UIBarButtonItem *)sender {
    [self resetPlayerResources];
    [self loadPlayer];
}

#pragma mark - Dealloc

- (void)resetPlayerResources
{
    if (_playerController) {
        [_playerController removeSessionConsumer:self];
        [_playerController pause];
        [_playerController pauseAd];
        [_playerController.view removeFromSuperview];
        _playerController = nil;
    }
    
    self.playerReady = NO;
    self.adPlaying = NO;
    self.videoPlaying = NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self resetPlayerResources];

    self.playerView = nil;
    self.adContext = nil;
    self.adManager = nil;
    self.adSlot = nil;
}

@end
