//
//  Midgar.h
//  TestApp2
//
//  Created by Bastien Beurier on 5/22/19.
//  Copyright © 2019 Bastien Beurier. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MidgarWindow : UIWindow

- (void)startWithAppToken:(NSString *)appToken;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
