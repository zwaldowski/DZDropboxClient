//
//  DZOAuth1Client.h
//  Markable
//
//  Created by Zachary Waldowski on 3/12/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "AFHTTPClient.h"

typedef enum {
    DZOAuthSignatureMethodPlaintext = 0,
    DZOAuthSignatureMethodHMAC_SHA1 = 1,
} DZOAuthSignatureMethod;

@class DZOAuth1Credential;

@interface DZOAuth1Client : AFHTTPClient

- (id)initWithBaseURL:(NSURL *)URL credential:(DZOAuth1Credential *)credential;
@property (nonatomic, readonly) DZOAuth1Credential *credential;

- (NSMutableURLRequest *)xAuthRequestForURL:(NSURL *)endpoint username:(NSString *)username password:(NSString *)password;

@end

@interface DZOAuth1Client (DZOAuthClasswideKeys)

+ (NSString *)consumerKey;
+ (NSString *)consumerSecret;

+ (DZOAuthSignatureMethod)signatureMethod;

+ (NSURL *)requestTokenURL;
+ (NSURL *)authorizationURL;
+ (NSURL *)accessTokenURL;

@end