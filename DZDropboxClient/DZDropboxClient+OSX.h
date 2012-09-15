//
//  DZDropboxClient+OSX.h
//  Markable
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxClient.h"

extern NSString *DZDropboxClientAuthenticationChangedNotification;

@interface DZDropboxClient (OSX)

@property (nonatomic, getter = isAuthenticating, readonly) BOOL authenticating;

- (void)link;
- (void)linkUserID:(NSString *)userID;
- (void)unlink;

@end
