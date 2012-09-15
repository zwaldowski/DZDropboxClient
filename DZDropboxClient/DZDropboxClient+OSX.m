//
//  DZDropboxClient+OSX.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxClient+OSX.h"
#import "AFJSONRequestOperation.h"
#import "DZOAuth1Credential.h"

#if defined(MAC_OS_X_VERSION_MIN_REQUIRED) && !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

extern NSString *DZDropboxAPIVersion;
extern NSString *DZDropboxWebHost;

NSString *DZDropboxClientAuthenticationChangedNotification = @"DZDropboxClientAuthenticationChangedNotification";

static void DZDropboxParseResponseString(NSString *result, NSString **pToken, NSString **pSecret, NSString **pUserID) {
	for (NSString *param in [result componentsSeparatedByString:@"&"]) {
		NSArray *vals = [param componentsSeparatedByString:@"="];
		if (vals.count != 2)
			return;
		
		NSString *name = components[0];
		NSString *val = components[1];
		
		if ([name isEqual:@"oauth_token"])
			*pToken = val;
		else if ([name isEqual:@"oauth_token_secret"])
			*pSecret = val;
		else if ([name isEqual:@"uid"] && pUserID)
			*pUserID = val;
	}
}

#pragma mark -

@interface DZDropboxClient ()

- (void)dz_resetCredential;
- (void)dz_setUserID:(NSString *)userID;
- (void)dz_setCredential:(DZOAuth1Credential *)credential;

@end

#pragma mark -

@implementation DZDropboxClient (OSX)

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)unlink {
    [self dz_resetCredential];
	[[NSNotificationCenter defaultCenter] postNotificationName:DZDropboxClientAuthenticationChangedNotification object:self];
}

- (void)link {
	[self linkUserID:self.userID];
}

- (void)linkUserID:(NSString *)userID {
	if (self.authenticating || self.linked)
		return;
	
	self.authenticating = YES;
	
	__block NSString *requestToken = nil;
	__block NSString *requestTokenSecret = nil;
	
	[self getPath:@"oauth/request_token" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		DZDropboxParseResponseString(operation.responseString, &requestToken, &requestTokenSecret, NULL);
		
		self.authenticating = NO;
		
		if (!requestToken.length)
			return;
		
		[[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			if (!requestToken.length || self.authenticating)
				return;
			
			self.authenticating = YES;
			
			[self getPath:@"oauth/access_token" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
				NSString *token = nil;
				NSString *secret = nil;
				NSString *uid = nil;
                
				DZDropboxParseResponseString(operation.responseString, &token, &secret, &uid);
                
                NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys: token, @"oauth_token", secret, @"oauth_token_secret", nil];
                [self dz_setCredential: [DZOAuth1Credential storeForServiceName: @"Dropbox" responseObject: params username: uid]];
                [self dz_setUserID: uid];

				self.authenticating = NO;
				[[NSNotificationCenter defaultCenter] removeObserver:self];
			} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				if (operation.response.statusCode == 403) {
					// request token probably no longer valid, clear it out to make sure we fetch another one
					requestToken = nil;
					requestTokenSecret = nil;
				}
				
				self.authenticating = NO;
			}];
		}];
				
		NSString *osxProtocol= [NSString stringWithFormat:@"db-%@", [[self class] consumerKey]];
		NSString *urlStr = [NSString stringWithFormat:@"https://%@/%@/oauth/authorize?oauth_token=%@&osx_protocol=%@", DZDropboxWebHost, DZDropboxAPIVersion, requestToken, osxProtocol];
		NSURL *url = [NSURL URLWithString:urlStr];

#TODO - do this in-app using WebView
		[[NSWorkspace sharedWorkspace] openURL:url];
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		self.authenticating = NO;
		if (!requestToken.length)
			[[NSNotificationCenter defaultCenter] removeObserver:self];
	}];
}

#pragma mark Properties

- (BOOL)isAuthenticating {
	return _dz_isAuthenticating;
}

- (void)setAuthenticating:(BOOL)authenticating {
	_dz_isAuthenticating = authenticating;
	[[NSNotificationCenter defaultCenter] postNotificationName:DZDropboxClientAuthenticationChangedNotification object:self];
}

@end

#endif