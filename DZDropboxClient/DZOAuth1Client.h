//
//  DZOAuth1Client.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/12/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "AFHTTPClient.h"

typedef NS_ENUM(NSUInteger, DZOAuthSignatureMethod) {
    DZOAuthSignatureMethodPlaintext,
    DZOAuthSignatureMethodHMAC_SHA1
};

@class DZOAuth1Credential;

@interface DZOAuth1Client : AFHTTPClient

- (id)initWithBaseURL:(NSURL *)URL credential:(DZOAuth1Credential *)credential;

@property (nonatomic, strong) DZOAuth1Credential *credential;

- (NSMutableURLRequest *)xAuthRequestForURL:(NSURL *)endpoint username:(NSString *)username password:(NSString *)password;

+ (NSString *)consumerKey;
+ (NSString *)consumerSecret;

+ (DZOAuthSignatureMethod)signatureMethod;

+ (NSURL *)requestTokenURL;
+ (NSURL *)authorizationURL;
+ (NSURL *)accessTokenURL;

@end