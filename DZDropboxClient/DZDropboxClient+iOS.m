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

static NSDictionary *DZDictionaryForURLQuery(NSURL *URL) {
	if (!URL.query.length)
		return nil;

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	NSScanner *parameterScanner = [[NSScanner alloc] initWithString: URL.query];

	while (![parameterScanner isAtEnd]) {
		NSString *key = nil;
		[parameterScanner scanUpToString:@"=" intoString:&key];
		[parameterScanner scanString:@"=" intoString:NULL];

		NSString *value = nil;
		[parameterScanner scanUpToString:@"&" intoString:&value];
		[parameterScanner scanString:@"&" intoString:NULL];

		if (!key.length && !value.length)
			continue;

		parameters[[key stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]] = [value stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	}
    return parameters;
}

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
	NSString *methodName = components.count > 1 ? components[1] : nil;
	
	if ([methodName isEqual:@"cancelled"])
		block();
		return NO;
	
	if (![methodName isEqual:@"connect"])
		return NO;
	
	NSDictionary *params = DZDictionaryForURLQuery(URL);
	self.credential = [DZOAuth1Credential storeForServiceName: @"Dropbox" responseObject: params username: params[@"uid"]];
    self.userID = params[@"uid"];
}

- (NSURL *)URLToLink {
	return [self URLToLinkUserID: self.userID];
}

- (NSURL *)URLToLinkUserID:(NSString *)userID {
	NSString *appScheme = [NSString stringWithFormat:@"db-%@", [[self class] consumerKey]];
    NSArray *urlTypes = [[NSBundle mainBundle] infoDictionary][@"CFBundleURLTypes"];
	BOOL conformsToScheme = ([urlTypes indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		NSArray *schemes = obj[@"CFBundleURLSchemes"];
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

	return [NSURL URLWithString:urlStr];
}

- (void)link {
	[self linkUserID:self.userID];
}

- (void)linkUserID:(NSString *)userID {
	NSURL *outgoingURL = [self URLToLinkUserID: userID];
	outgoingClient = self;
	[[UIApplication sharedApplication] openURL: outgoingURL];
}

- (void)unlink {
	[self.credential evict];
	self.userID = nil;
}

@end

#endif