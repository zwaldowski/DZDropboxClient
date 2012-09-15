//
//  DZDropboxClient+iOS.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxClient+iOS.h"
#import "DZOAuth1Credential.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

#import <CommonCrypto/CommonDigest.h>

extern NSString *DZDropboxUnknownUserID;
extern NSString *DZDropboxAPIVersion;
extern NSString *DZDropboxProtocol;
extern NSString *DZDropboxWebHost;

extern NSDictionary * DZParametersFromURLQuery(NSURL *URL);

@interface DZDropboxClient ()

- (void)dz_resetCredential;
- (void)dz_setUserID:(NSString *)userID;
- (void)dz_setCredential:(DZOAuth1Credential *)credential;

@end

static DZDropboxClient *outgoingClient = nil;

#pragma mark -

@implementation DZDropboxClient (iOS)

+ (BOOL)handleOpenURL:(NSURL *)URL {
	return [self handleOpenURL:URL cancelled:NULL];
}

- (BOOL)handleOpenURL:(NSURL *)URL {
	return [self handleOpenURL:URL cancelled:NULL];
}

+ (BOOL)handleOpenURL:(NSURL *)URL cancelled:(void(^)(void))block {
	if (!outgoingClient)
		return NO;
	return [outgoingClient handleOpenURL:URL];
}

- (BOOL)handleOpenURL:(NSURL *)URL cancelled:(void(^)(void))block {
	NSParameterAssert(URL);
	
	NSString *expected = [NSString stringWithFormat:@"%@://%@/", [NSString stringWithFormat:@"db-%@", [[self class] consumerKey]], DZDropboxAPIVersion];
	if (![URL.absoluteString hasPrefix:expected])
		return NO;

	NSArray *components = URL.path.pathComponents;
	NSString *methodName = components.count > 1 ? [components objectAtIndex:1] : nil;
	
	if ([methodName isEqual:@"cancelled"])
		block();
		return NO;
	
	if (![methodName isEqual:@"connect"])
		return NO;
	
	NSDictionary *params = DZParametersFromURLQuery(URL);
	NSString *userID = [params objectForKey:@"uid"];
	
    [self dz_setCredential: [DZOAuth1Credential storeForServiceName: @"Dropbox" responseObject: params username: userID]];
    [self dz_setUserID: userID];
}

- (void)link {
	[self linkUserID:self.userID];
}

- (void)linkUserID:(NSString *)userID {
	NSAssert([[self class] consumerKey] && [[self class] consumerSecret], @"Please set a consumer key and secret!");
    NSString *appScheme = [NSString stringWithFormat:@"db-%@", [[self class] consumerKey]];
    NSArray *urlTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
	BOOL conformsToScheme = ([urlTypes indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		NSArray *schemes = [obj objectForKey:@"CFBundleURLSchemes"];
		return ([schemes indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			if ([obj isEqualToString: appScheme]) {
				*stop = YES;
				return YES;
			}
			return NO;
		}] != NSNotFound);
	}] != NSNotFound);
	NSAssert(conformsToScheme, @"App does not conform to consumer key URL protocol!");
	
	NSString *userIdStr = [userID isEqual:DZDropboxUnknownUserID] ? @"" : [NSString stringWithFormat:@"&u=%@", userID];
	NSString *consumerKey = [[self class] consumerKey];
	NSData *consumerSecret = [[[self class] consumerSecret] dataUsingEncoding:NSUTF8StringEncoding];

	unsigned char md[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1(consumerSecret.bytes, consumerSecret.length, md);
	NSUInteger sha_32 = htonl(((NSUInteger *)md)[CC_SHA1_DIGEST_LENGTH/sizeof(NSUInteger) - 1]);
	NSString *secret = [NSString stringWithFormat:@"%x", sha_32];
	
	NSURL *dbURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/connect", DZDropboxProtocol, DZDropboxAPIVersion]];
	NSString *urlStr = [[UIApplication sharedApplication] canOpenURL:dbURL] ? [NSString stringWithFormat:@"%@?k=%@&s=%@%@", dbURL, consumerKey, secret, userIdStr] : [NSString stringWithFormat:@"https://%@/%@/connect?k=%@&s=%@&dca=1&%@", DZDropboxWebHost, DZDropboxAPIVersion, consumerKey, secret, userIdStr];
	outgoingClient = self;
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
}

- (void)unlink {
    [self dz_resetCredential];
}

@end

#endif