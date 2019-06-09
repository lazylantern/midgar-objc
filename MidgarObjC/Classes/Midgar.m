//
//  Midgar.m
//
//  Created by Bastien Beurier on 5/22/19.
//  Copyright © 2019 Lazy Lantern. All rights reserved.
//

#import "Midgar.h"
#import <sys/utsname.h>
#include "TargetConditionals.h"

#pragma mark - Constants

BOOL const LogsEnabled = NO;
float const DetectionFrequency = 0.5; // in seconds
float const UploadFrequency = 60.0; // in seconds
NSString *const BaseUrl = @"https://midgar-flask.herokuapp.com/api";
NSString *const EventTypeImpression = @"impression";
NSString *const EventTypeForeground = @"foreground";
NSString *const EventTypeBackground = @"background";
int const SessionIdLength = 6;
long long const SessionExpiration = 10 * 60 * 1000; // 10 mins in milliseconds

#pragma mark - Logger

void MidgarLog(NSString *format, ...) {
    if(!LogsEnabled)
        return;
    va_list args;
    va_start(args, format);
    NSLogv([@"Midgar log: " stringByAppendingString:format], args);
    va_end(args);
}

#pragma mark - Session Class Interface

@interface MidgarSession : NSObject

+ (NSString *)sessionId;
+ (NSString *)platform;
+ (NSString *)sdk;
+ (NSString *)country;
+ (NSString *)osVersion;
+ (NSString *)appName;
+ (NSString *)versionName;
+ (NSString *)versionCode;
+ (NSString *)deviceManufacturer;
+ (NSString *)deviceModel;
+ (bool)isEmulator;

@end

#pragma mark - Event Class Interface

@interface MidgarEvent : NSObject

@property (strong, nonatomic) NSString *type;
@property (strong, nonatomic) NSString *screen;
@property (strong, nonatomic) NSString *deviceId;
@property (nonatomic) long long timestamp;
@property (strong, nonatomic) NSString *sessionId;
@property (strong, nonatomic) NSString *platform;
@property (strong, nonatomic) NSString *sdk;
@property (strong, nonatomic) NSString *country;
@property (strong, nonatomic) NSString *osVersion;
@property (strong, nonatomic) NSString *appName;
@property (strong, nonatomic) NSString *versionName;
@property (strong, nonatomic) NSString *versionCode;
@property (strong, nonatomic) NSString *deviceManufacturer;
@property (strong, nonatomic) NSString *deviceModel;
@property (nonatomic) bool isEmulator;

- (id)initWithType:(NSString *)type
            screen:(NSString *)screen
          deviceId:(NSString *)deviceId;

+ (NSArray *)toDicts:(NSArray <MidgarEvent *> *)events;

@end

#pragma mark - Session Class Implementation

@implementation MidgarSession

static MidgarEvent *_lastEvent;
static NSString *_sessionId;
static NSString *_country;
static NSString *_osVersion;
static NSString *_appName;
static NSString *_versionName;
static NSString *_versionCode;
static NSString *_deviceManufacturer;
static NSString *_deviceModel;
static bool _isEmulator;

+ (void)setLastEvent:(MidgarEvent *)event {
    _lastEvent = event;
}

+ (NSString *)generateSessionId {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:SessionIdLength];
    
    for (int i = 0; i < SessionIdLength; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex:arc4random_uniform((int)[letters length])]];
    }
    
    return randomString;
}

+ (NSString *)sessionId {
    if (!_sessionId || !_lastEvent) { // First event in session.
        _sessionId = [MidgarSession generateSessionId];
        return _sessionId;
    }
    
    if (![_lastEvent.type isEqualToString:EventTypeBackground]) { // App was in foreground.
        return _sessionId;
    }
    
    long long backgroundDuration = ((long long)([[NSDate date] timeIntervalSince1970] * 1000.0)) - _lastEvent.timestamp;
    if (backgroundDuration > SessionExpiration) { // App was in background.
        _sessionId = [MidgarSession generateSessionId]; // Session expired.
    }
    
    return _sessionId;
}

+ (NSString *)platform {
    return @"ios";
}

+ (NSString *)sdk {
    return @"swift";
}

+ (NSString *)country {
    if (!_country) {
        _country = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
    }
    
    return _country;
}

+ (NSString *)osVersion {
    if (!_osVersion) {
        _osVersion = UIDevice.currentDevice.systemVersion;
    }
    
    return _osVersion;
}

+ (NSString *)appName {
    if (!_appName) {
        _appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    }
    
    return _appName;
}

+ (NSString *)versionName {
    if (!_versionName) {
        _versionName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    }
    
    return _versionName;
}

+ (NSString *)versionCode {
    if (!_versionCode) {
        _versionCode = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    }
    
    return _versionCode;
}

+ (NSString *)deviceManufacturer {
    return @"Apple";
}

+ (NSString *)deviceModel {
    if (!_deviceModel) {
        struct utsname systemInfo;
        uname(&systemInfo);
        _deviceModel = [NSString stringWithCString:systemInfo.machine
                                            encoding:NSUTF8StringEncoding];
    }
    
    return _deviceModel;
}

+ (bool)isEmulator {
    if (!_isEmulator) {
        #if TARGET_OS_SIMULATOR
        _isEmulator = YES;
        #else
        _isEmulator = NO;
        #endif
    }
    
    return _isEmulator;
}

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
        self.sessionId = MidgarSession.sessionId;
        self.platform = MidgarSession.platform;
        self.sdk = MidgarSession.sdk;
        self.country = MidgarSession.country;
        self.osVersion = MidgarSession.osVersion;
        self.appName = MidgarSession.appName;
        self.versionName = MidgarSession.versionName;
        self.versionCode = MidgarSession.versionCode;
        self.deviceManufacturer = MidgarSession.deviceManufacturer;
        self.deviceModel = MidgarSession.deviceModel;
        self.isEmulator = MidgarSession.isEmulator;
        [MidgarSession setLastEvent:self];
        MidgarLog(@"new event -> %@", [self toDict]);
    }
    return self;
}

- (NSDictionary *)toDict {
    return @{
             @"type": self.type,
             @"screen": self.screen,
             @"device_id": self.deviceId,
             @"timestamp": [NSNumber numberWithLongLong:self.timestamp],
             @"session_id": self.sessionId,
             @"platform": self.platform,
             @"sdk": self.sdk,
             @"country": self.country,
             @"os_version": self.osVersion,
             @"app_name": self.appName,
             @"version_name": self.versionName,
             @"version_code": self.versionCode,
             @"manufacturer": self.deviceManufacturer,
             @"model": self.deviceModel,
             @"is_emulator": [NSNumber numberWithBool:self.isEmulator]
             };
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

- (void)uploadBatchWithEvents:(NSArray <MidgarEvent *> *)events
                     appToken:(NSString *)appToken
                   completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion;

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

- (void)uploadBatchWithEvents:(NSArray <MidgarEvent *> *)events
                     appToken:(NSString *)appToken
                   completion:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    NSDictionary *parameters = @{
                                 @"events": [MidgarEvent toDicts:events],
                                 @"app_token": appToken
                                 };
    NSString *url = [BaseUrl stringByAppendingString:@"/events"];
    NSURLRequest *request = [self createPostRequestWithUrl:url parameters:parameters];
    
    if (!request) { return; }
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completion] resume];
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

#pragma mark - MidgarWindow Public Methods

- (void)startWithAppToken:(NSString *)appToken {
    if (self.started) { return; }
    
    self.started = YES;
    [self setUpInitialValues];
    self.appToken = appToken;
    [self subscribeToNotifications];
    [self checkAppEnabled];
}

- (void)stop {
    [self stopMonitoring];
}

#pragma mark - MidgarWindow Private Methods
    
- (void)setUpInitialValues {
    self.eventBatch = [[NSMutableArray alloc] init];
    self.eventUploadService = [[MidgarUploadService alloc] init];
    self.deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

- (void)checkAppEnabled {
    __weak typeof(self) weakSelf = self;
    [self.eventUploadService checkKillSwitchWithAppToken:self.appToken
                                              completion:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
                                                          [((NSHTTPURLResponse *)response) statusCode] == 200) {
                                                          MidgarLog(@"Kill switch OFF");
                                                          [weakSelf startMonitoring];
                                                      } else {
                                                          MidgarLog(@"Kill switch ON");
                                                          [weakSelf stopMonitoring];
                                                      }
                                                  });
                                                  
    }];
}

- (void)startMonitoring {
    if (self.screenDetectionTimer || self.eventUploadTimer) {
        return;
    }
    
    self.screenDetectionTimer = [NSTimer scheduledTimerWithTimeInterval:DetectionFrequency
                                                                 target:self
                                                               selector:@selector(detectScreen:)
                                                               userInfo:nil
                                                                repeats:YES];
    
    self.eventUploadTimer = [NSTimer scheduledTimerWithTimeInterval:UploadFrequency
                                                                 target:self
                                                               selector:@selector(uploadEventsIfNeeded:)
                                                               userInfo:nil
                                                                repeats:YES];
}

- (void)detectScreen:(id)userInfo {
    NSString *currentScreen = [self topViewControllerDescription];
    
    if (![currentScreen isEqualToString:self.currentScreen]) {
        self.currentScreen = currentScreen;
        MidgarEvent *event = [[MidgarEvent alloc] initWithType:EventTypeImpression
                                                        screen:currentScreen
                                                      deviceId:self.deviceId];
        [self.eventBatch addObject:event];
    }
}

- (void)uploadEventsIfNeeded:(id)userInfo {
    if (self.eventBatch.count > 0) {
        MidgarLog(@"Uploading %d events.", self.eventBatch.count);
        [self.eventUploadService uploadBatchWithEvents:self.eventBatch
                                              appToken:self.appToken
                                            completion:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
                                                        [((NSHTTPURLResponse *)response) statusCode] == 201) {
                                                        MidgarLog(@"Upload successful.");
                                                    } else {
                                                        MidgarLog(@"Upload failed.");
                                                    }
                                                });
                                            }];
        [self.eventBatch removeAllObjects];
    } else {
        MidgarLog(@"No event to upload.");
    }
}

- (void)stopMonitoring {
    [self.screenDetectionTimer invalidate];
    [self.eventUploadTimer invalidate];
    self.screenDetectionTimer = nil;
    self.eventUploadTimer = nil;
    [self unsubscribeFromNotifications];
    self.started = NO;
}

- (void)subscribeToNotifications {
    [self unsubscribeFromNotifications];
    
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
    [self uploadEventsIfNeeded:nil];
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
