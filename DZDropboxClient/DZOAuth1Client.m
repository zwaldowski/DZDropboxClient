//
//  DZOAuth1Client.m
//  Markable
//
//  Created by Zachary Waldowski on 3/12/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZOAuth1Client.h"
#import "AFHTTPRequestOperation.h"
#import <CommonCrypto/CommonHMAC.h>
#import "DZOAuth1Credential.h"

extern NSString * AFQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding);

static NSString *const DZOAuth1Version = @"1.0";

static NSString *const DZOAuthHeaderVersionKey			= @"oauth_version";
static NSString *const DZOAuthHeaderSignatureMethodKey	= @"oauth_signature_method";
static NSString *const DZOAuthHeaderTimestampKey		= @"oauth_timestamp";
static NSString *const DZOAuthHeaderNonceKey			= @"oauth_nonce";
static NSString *const DZOAuthHeaderSignatureKey		= @"oauth_signature";
static NSString *const DZOAuthHeaderVerifierKey			= @"oauth_verifier";
static NSString *const DZOAuthHeaderConsumerKey			= @"oauth_consumer_key";
static NSString *const DZOAuthHeaderTokenKey			= @"oauth_token";

static NSString *const DZOAuthSignatureMethodName[] = {
    @"PLAINTEXT",
    @"HMAC-SHA1",
};

static NSDictionary *DZURLQueryDictionary(NSURL *URL) {
	NSArray *pairs = [URL.query componentsSeparatedByString:@"&"];
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:pairs.count];
    [pairs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray *elements = [obj componentsSeparatedByString:@"="];
        NSString *key = [elements objectAtIndex:0];
        NSString *value = (elements.count > 1) ? [elements objectAtIndex:1] : @"";
        [parameters setObject:value forKey:key];
    }];
	return parameters;
}

static NSString *DZOAuthSignature(NSString *base, DZOAuthSignatureMethod method, NSString *consumerSecret, NSString *tokenSecret) {
	NSString *plaintextSignature = [NSString stringWithFormat:@"%@&%@", 
									consumerSecret.length ? consumerSecret : @"",
									tokenSecret.length ? tokenSecret : @""];
	
	if (method == DZOAuthSignatureMethodHMAC_SHA1) {
		const char *keyBytes = [plaintextSignature cStringUsingEncoding:NSUTF8StringEncoding];
		const char *baseStringBytes = [base cStringUsingEncoding:NSUTF8StringEncoding];
		unsigned char digestBytes[CC_SHA1_DIGEST_LENGTH];
		
		CCHmacContext ctx;
		CCHmacInit(&ctx, kCCHmacAlgSHA1, keyBytes, strlen(keyBytes));
		CCHmacUpdate(&ctx, baseStringBytes, strlen(baseStringBytes));
		CCHmacFinal(&ctx, digestBytes);

		NSData *data = [NSData dataWithBytes:digestBytes length:CC_SHA1_DIGEST_LENGTH];
		NSUInteger length = [data length];
		NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
		
		uint8_t *input = (uint8_t *)[data bytes];
		uint8_t *output = (uint8_t *)[mutableData mutableBytes];
		
		for (NSUInteger i = 0; i < length; i += 3) {
			NSUInteger value = 0;
			for (NSUInteger j = i; j < (i + 3); j++) {
				value <<= 8;
				if (j < length) {
					value |= (0xFF & input[j]); 
				}
			}
			
			static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
			
			NSUInteger idx = (i / 3) * 4;
			output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
			output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
			output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
			output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
		}
		
		return [[NSString alloc] initWithData:mutableData encoding:NSUTF8StringEncoding];		
	}
	
	return plaintextSignature;
}

@interface DZOAuth1Client ()

@property (nonatomic, strong) NSMutableDictionary *OAuthValues;
@property (nonatomic, copy) NSString *secret;

@end

@implementation DZOAuth1Client

- (id)initWithBaseURL:(NSURL *)URL credential:(DZOAuth1Credential *)credential {
    if ((self = [self initWithBaseURL: URL])) {
        _credential = credential;
        self.secret = credential.secret;
    }
    return self;
}

- (id)initWithBaseURL:(NSURL *)url {
	NSAssert([[self class] consumerKey] && [[self class] consumerSecret], @"Please set a consumer key and secret!");
	if ((self = [super initWithBaseURL:url])) {
		self.OAuthValues = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							DZOAuth1Version, DZOAuthHeaderVersionKey,
                            DZOAuthSignatureMethodName[[[self class] signatureMethod]], DZOAuthHeaderSignatureMethodKey,
							[[self class] consumerKey] ?: @"", DZOAuthHeaderConsumerKey,
							self.credential.token ?: @"", DZOAuthHeaderTokenKey,
							self.credential.verifier ?: @"", DZOAuthHeaderVerifierKey,
							@"", DZOAuthHeaderSignatureKey,
							@"", DZOAuthHeaderTimestampKey,
							@"", DZOAuthHeaderNonceKey,
							nil];
	}
	return self;
}

#pragma mark - Properties

- (void)dz_setCredential:(DZOAuth1Credential *)credential {
    if (credential == _credential)
        return;
    
    _credential = credential;
    
    [self.OAuthValues setObject:_credential.token forKey:DZOAuthHeaderTokenKey];
	[self.OAuthValues setObject:_credential.verifier.length ? credential.verifier : @"" forKey:DZOAuthHeaderTokenKey];
    self.secret = _credential.secret;
}

#pragma mark - Request Signing

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	NSAssert([[self class] consumerKey] && [[self class] consumerSecret], @"Please set a consumer key and secret!");

	NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
	request.timeoutInterval = 20;
	request.HTTPShouldHandleCookies = NO;
	
	NSMutableDictionary *headers = [self.OAuthValues mutableCopy];
	
    // Generate timestamp
	NSString *timestamp = [NSString stringWithFormat:@"%d", (int)[[NSDate date] timeIntervalSince1970]];
	[headers setObject:timestamp forKey:DZOAuthHeaderTimestampKey];
	
	// Generate nonce
	CFUUIDRef UUID = CFUUIDCreate(NULL);
	NSString *nonce = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
	CFRelease(UUID);
	[headers setObject:nonce forKey:DZOAuthHeaderNonceKey];
	
	// Filter out empty headers
	NSSet *keysToRemove = [headers keysOfEntriesPassingTest:^BOOL(id key, NSString *obj, BOOL *stop) {
		return !obj.length;
	}];
	[headers removeObjectsForKeys: keysToRemove.allObjects];

    // Add parameters from the query string
    NSMutableDictionary *query = [DZURLQueryDictionary(request.URL) mutableCopy];
	
	[query addEntriesFromDictionary:headers];
	
	// Add parameters from the request body
    // Only if we're POSTing, GET parameters were already added
    if ([request.HTTPMethod.uppercaseString isEqualToString:@"POST"])
        [query addEntriesFromDictionary:parameters];
	
	NSString *parameterString = AFQueryStringFromParametersWithEncoding(query, NSUTF8StringEncoding);
	
	// Get the base URL String (with no parameters)
	NSString *URLString = [request.URL absoluteString];
    NSArray *URLParts = [URLString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"?#"]];
    NSString *URLBase = [URLParts objectAtIndex:0];
	
	NSString *baseString = [NSString stringWithFormat:@"%@&%@&%@", request.HTTPMethod.uppercaseString, [URLBase stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], parameterString];
	[headers setValue:DZOAuthSignature(baseString, [[self class] signatureMethod], [[self class] consumerSecret], self.secret) forKey:DZOAuthHeaderSignatureKey];
	
	NSString *oauthString = [NSString stringWithFormat:@"OAuth %@",  AFQueryStringFromParametersWithEncoding(headers, NSUTF8StringEncoding)];
	[request setValue:oauthString forHTTPHeaderField:@"Authorization"];
	
	return request;
}

- (NSMutableURLRequest *)xAuthRequestForURL:(NSURL *)endpoint username:(NSString *)username password:(NSString *)password {
	return [self requestWithMethod:@"POST" path:endpoint.absoluteString parameters:@{
        @"x_auth_mode" : @"client_auth",
        @"x_auth_username" : username,
        @"x_auth_password" : password
    }];
}

@end

@implementation DZOAuth1Client (DZOAuthClasswideKeys)

static NSString *const DZOAuthSubclassMethod = @"DZOAuthSubclassMethod";

+ (DZOAuthSignatureMethod)signatureMethod {
    return DZOAuthSignatureMethodPlaintext;
}

+ (NSString *)consumerKey {
    [NSException raise:DZOAuthSubclassMethod format:@"Method +%@ must be implemented on %@", NSStringFromSelector(_cmd), NSStringFromClass(self)];
    return nil;
}

+ (NSString *)consumerSecret {
    [NSException raise:DZOAuthSubclassMethod format:@"Method +%@ must be implemented on %@", NSStringFromSelector(_cmd), NSStringFromClass(self)];
    return nil;
}

+ (NSURL *)requestTokenURL {
    [NSException raise:DZOAuthSubclassMethod format:@"Method +%@ must be implemented on %@", NSStringFromSelector(_cmd), NSStringFromClass(self)];
    return nil;    
}

+ (NSURL *)authorizationURL {
    [NSException raise:DZOAuthSubclassMethod format:@"Method +%@ must be implemented on %@", NSStringFromSelector(_cmd), NSStringFromClass(self)];
    return nil;    
}

+ (NSURL *)accessTokenURL {
    [NSException raise:DZOAuthSubclassMethod format:@"Method +%@ must be implemented on %@", NSStringFromSelector(_cmd), NSStringFromClass(self)];
    return nil;    
}

@end
