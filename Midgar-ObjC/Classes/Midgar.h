//
//  Midgar.h
//
//  Created by Bastien Beurier on 5/22/19.
//  Copyright © 2019 Lazy Lantern. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MidgarWindow : UIWindow

- (void)startWithAppToken:(NSString *)appToken;

- (void)stop;

@end
