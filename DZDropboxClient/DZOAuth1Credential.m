//
//  DZOAuth1Credential.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 4/18/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZOAuth1Credential.h"

@implementation DZOAuth1Credential

@dynamic token, secret, verifier;

+ (id)storeForServiceName:(NSString *)name responseObject:(id)data username:(NSString *)username {
	NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
							  [data valueForKey: @"oauth_token"], @"token",
							  [data valueForKey: @"oauth_token_secret"], @"secret",
							  nil];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject: [data valueForKey: @"oauth_verifier"] forKey: @"verifier"];
	return [self storeForServiceName: name username: username contents: contents userInfo: userInfo];
}

#pragma mark -

+ (NSSet *)keyPathsForValuesAffectingContents {
    return [NSSet setWithObjects: @"token", @"secret", nil];
}

+ (NSSet *)keyPathsForValuesAffectingUserInfo {
	return [NSSet setWithObject:@"verifier"];
}

@end

@implementation DZOMutableAuth1Credential

@dynamic token, secret, verifier;

@end