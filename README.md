# Midgar

[![CI Status](https://img.shields.io/travis/bastienbeurier/Midgar.svg?style=flat)](https://travis-ci.org/bastienbeurier/Midgar)
[![Version](https://img.shields.io/cocoapods/v/Midgar.svg?style=flat)](https://cocoapods.org/pods/Midgar)
[![License](https://img.shields.io/cocoapods/l/Midgar.svg?style=flat)](https://cocoapods.org/pods/Midgar)
[![Platform](https://img.shields.io/cocoapods/p/Midgar.svg?style=flat)](https://cocoapods.org/pods/Midgar)

## Requirements

iOS > 10.0

## Installation

Midgar is available through CocoaPods. 

To install it, simply add the following line to your Podfile:

```ruby
pod 'Midgar'
```

Run `pod install`.

The integration entirely happens in the `AppDelegate.m` implementation file.

Import the header file:

```
#import <Midgar/Midgar.h>
```

Declare the `midgarWindow` property:

```
@interface AppDelegate ()

@property (nonatomic, strong) MidgarWindow *midgarWindow;

@end
```

Add a getter for the `window` property:

```
@implementation AppDelegate

- (UIWindow *)window {
    if (!self.midgarWindow) {
        self.midgarWindow = [[MidgarWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    return self.midgarWindow;
}
```

Start the Midgar SDK:

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [self.midgarWindow startWithAppToken:@"your-app-token-provided-by-lazy-lantern"];
    
    return YES;
}
```

You're done!

## Author

SDK edited by Lazy Lantern inc. 

For any assitance or trouble shouting, please contact us at founders@lazylantern.com.

## License

Midgar is available under the Apache license. See the LICENSE file for more info.
