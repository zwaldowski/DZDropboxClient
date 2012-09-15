//
//  DZDropboxClient+iOS.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxClient.h"

@interface DZDropboxClient (iOS)

+ (BOOL)handleOpenURL:(NSURL *)URL;
- (BOOL)handleOpenURL:(NSURL *)URL;
+ (BOOL)handleOpenURL:(NSURL *)URL cancelled:(void(^)(void))block;
- (BOOL)handleOpenURL:(NSURL *)URL cancelled:(void(^)(void))block;

- (void)link;
- (void)linkUserID:(NSString *)userID;
- (void)unlink;

@end