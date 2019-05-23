//
//  Midgar.m
//
//  Created by Bastien Beurier on 5/22/19.
//  Copyright © 2019 Lazy Lantern. All rights reserved.
//

#import "Midgar.h"

#pragma mark - Constants

BOOL const LogsEnabled = NO;
float const DetectionFrequency = 0.5; // in seconds
float const UploadFrequency = 10.0; // in seconds
NSString *const BaseUrl = @"https://midgar-flask.herokuapp.com/api";
NSString *const EventTypeImpression = @"impression";
NSString *const EventTypeForeground = @"foreground";
NSString *const EventTypeBackground = @"background";

#pragma mark - Logger

void MidgarLog(NSString *format, ...) {
    if(!LogsEnabled)
        return;
    va_list args;
    va_start(args, format);
    NSLogv([@"Midgar log: " stringByAppendingString:format], args);
    va_end(args);
}

#pragma mark - Event Class Interface

@interface MidgarEvent : NSObject

@property (strong, nonatomic) NSString *type;
@property (strong, nonatomic) NSString *screen;
@property (strong, nonatomic) NSString *deviceId;
@property (nonatomic) long long timestamp;

- (id)initWithType:(NSString *)type
            screen:(NSString *)screen
          deviceId:(NSString *)deviceId;

+ (NSArray *)toDicts:(NSArray <MidgarEvent *> *)events;

@end

#pragma mark - Event Class Implementation

@implementation MidgarEvent

- (id)initWithType:(NSString *)type
            screen:(NSString *)screen
          deviceId:(NSString *)deviceId {
    if (self = [super init])  {
        self.type = type;
        self.screen = screen;
        self.deviceId = deviceId;
        self.timestamp = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        [self log];
    }
    return self;
}

- (NSDictionary *)toDict {
    return @{
             @"type": self.type,
             @"screen": self.screen,
             @"device_id": self.deviceId,
             @"timestamp": [NSNumber numberWithLongLong:self.timestamp],
             @"platform": @"ios",
             @"sdk": @"objc"
             };
}

- (void)log {
    MidgarLog(@"Event %@, screen %@, id %@, timestamp %lld", self.type, self.screen, self.deviceId, self.timestamp);
}

+ (NSArray *)toDicts:(NSArray <MidgarEvent *> *)events {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (MidgarEvent *event in events) {
        [result addObject:[event toDict]];
    }
    
    return result;
}

@end

#pragma mark - EventUploadService Class Interface

@interface MidgarUploadService : NSObject

- (void)checkKillSwitchWithAppToken:(NSString *)appToken
                         completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion;

- (void)uploadBatchWithEvents:(NSArray <MidgarEvent *> *)events appToken:(NSString *)appToken;

@end

#pragma mark - EventUploadService Class Implementation

@implementation MidgarUploadService

- (void)checkKillSwitchWithAppToken:(NSString *)appToken
                         completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    
    NSDictionary *parameters = @{ @"app_token": appToken };
    NSString *url = [BaseUrl stringByAppendingString:@"/apps/kill"];
    NSURLRequest *request = [self createPostRequestWithUrl:url parameters:parameters];
    
    if (!request) { return; }
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completion] resume];
}

- (void)uploadBatchWithEvents:(NSArray <MidgarEvent *> *)events appToken:(NSString *)appToken {
    NSDictionary *parameters = @{
                                 @"events": [MidgarEvent toDicts:events],
                                 @"app_token": appToken
                                 };
    NSString *url = [BaseUrl stringByAppendingString:@"/events"];
    NSURLRequest *request = [self createPostRequestWithUrl:url parameters:parameters];
    
    if (!request) { return; }
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (NSURLRequest *)createPostRequestWithUrl:(NSString *)urlString parameters:(NSDictionary *)parameters {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSError *error = [[NSError alloc] init];
    NSData *body = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
    
    if (!body) {
        MidgarLog(@"Lazy Lantern: HTTP body serialization error: %@", error);
        return nil;
    }
    
    [request setHTTPBody:body];
    return request;
}

@end

#pragma mark - MidgarWindow Class Interface

@interface MidgarWindow ()

@property (strong, nonatomic) NSMutableArray<MidgarEvent *> *eventBatch;
@property (strong, nonatomic) NSTimer *screenDetectionTimer;
@property (strong, nonatomic) NSTimer *eventUploadTimer;
@property (strong, nonatomic) MidgarUploadService *eventUploadService;
@property (strong, nonatomic) NSString *currentScreen;
@property (strong, nonatomic) NSString *appToken;
@property (strong, nonatomic) NSString *deviceId;
@property (nonatomic) BOOL started;
@property (nonatomic) int uploadTimerLoopCount;

@end

#pragma mark - MidgarWindow Class Implementation

@implementation MidgarWindow

#pragma mark - MidgarWindow Initialization Methods

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame])  {
        [self setUpInitialValues];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder])  {
        [self setUpInitialValues];
    }
    return self;
}

- (void)setUpInitialValues {
    self.eventBatch = [[NSMutableArray alloc] init];
    self.eventUploadService = [[MidgarUploadService alloc] init];
    self.deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

#pragma mark - MidgarWindow Public Methods

- (void)startWithAppToken:(NSString *)appToken {
    if (self.started) { return; }
    
    self.appToken = appToken;
    self.started = YES;
    [self subscribeToNotifications];
    [self checkAppEnabled];
}

- (void)stop {
    [self stopMonitoring];
}

#pragma mark - MidgarWindow Private Methods

- (void)checkAppEnabled {
    __weak typeof(self) weakSelf = self;
    [self.eventUploadService checkKillSwitchWithAppToken:self.appToken
                                              completion:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
                                                          [((NSHTTPURLResponse *)response) statusCode] == 200) {
                                                          [weakSelf startMonitoring];
                                                      } else {
                                                          [weakSelf stopMonitoring];
                                                      }
                                                  });
                                                  
    }];
}

- (void)startMonitoring {
    if (self.screenDetectionTimer || self.eventUploadTimer) {
        return;
    }
    
    self.screenDetectionTimer = [NSTimer scheduledTimerWithTimeInterval:DetectionFrequency repeats:YES block:^(NSTimer *timer) {
        NSString *currentScreen = [self topViewControllerDescription];
        
        if (![currentScreen isEqualToString:self.currentScreen]) {
            self.currentScreen = currentScreen;
            MidgarEvent *event = [[MidgarEvent alloc] initWithType:EventTypeImpression
                                                            screen:currentScreen
                                                          deviceId:self.deviceId];
            [self.eventBatch addObject:event];
        }
    }];
    
    self.eventUploadTimer = [NSTimer scheduledTimerWithTimeInterval:UploadFrequency repeats:YES block:^(NSTimer *timer) {
        if (self.eventBatch.count > 0) {
            [self.eventUploadService uploadBatchWithEvents:self.eventBatch appToken:self.appToken];
            [self.eventBatch removeAllObjects];
        }
    }];
}

- (void)stopMonitoring {
    [self.screenDetectionTimer invalidate];
    [self.eventUploadTimer invalidate];
    self.screenDetectionTimer = nil;
    self.eventUploadTimer = nil;
    self.started = NO;
    [self unsubscribeFromNotifications];
}

- (void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appForegrounded:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appBackgrounded:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)unsubscribeFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appForegrounded:(NSNotification *)notification {
    MidgarEvent *event = [[MidgarEvent alloc] initWithType:EventTypeForeground
                                                    screen:@""
                                                  deviceId:self.deviceId];
    [self.eventBatch addObject:event];
}

- (void)appBackgrounded:(NSNotification *)notification {
    MidgarEvent *event = [[MidgarEvent alloc] initWithType:EventTypeBackground
                                                    screen:@""
                                                  deviceId:self.deviceId];
    [self.eventBatch addObject:event];
}

- (UIViewController *)topViewControllerFromViewController:(UIViewController *)vc {
    if (!vc) {
        vc = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    }
    
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UIViewController *visibleVC = [(UINavigationController *)vc visibleViewController];
        
        if (visibleVC) {
            return [self topViewControllerFromViewController:visibleVC];
        }
    }
    
    if ([vc isKindOfClass:[UITabBarController class]]) {
        UIViewController *selectedVC = [(UITabBarController *)vc selectedViewController];
        
        if (selectedVC) {
            return [self topViewControllerFromViewController:selectedVC];
        }
    }

    UIViewController *presentedVC = [vc presentedViewController];
    if (presentedVC) {
        return [self topViewControllerFromViewController:presentedVC];
    }
    
    return vc;
}

- (NSString *)topViewControllerDescription {
    UIViewController *topVC = [self topViewControllerFromViewController:nil];
    
    if (topVC) {
        return NSStringFromClass([topVC class]);
    } else {
        return @"";
    }
}

@end
