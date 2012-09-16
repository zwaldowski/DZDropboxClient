//
//  DZOAuth1Client.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/12/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZOAuth1Client.h"
#import "AFHTTPRequestOperation.h"
#import <CommonCrypto/CommonHMAC.h>
#import "DZOAuth1Credential.h"

#define DZConcreteImplementation(baseClass) _DZConcreteImplementation(self, _cmd, baseClass)

extern void _DZConcreteImplementation(id obj, SEL sel, Class cls) {
	Class objectClass = [obj class];
	const char *annotate = "-";
	if (obj == objectClass)
		annotate = "+";
	NSString *selector = NSStringFromSelector(sel);
	[NSException raise: NSInvalidArgumentException format: @"%s%@ only defined for abstract class %@.  Define %s[%@ %@]!", annotate, selector, NSStringFromClass(cls), annotate, objectClass, selector];
}

static NSString *const DZOAuth1Version = @"1.0";

static NSString *const DZOAuthHeaderVersionKey			= @"oauth_version";
static NSString *const DZOAuthHeaderSignatureMethodKey	= @"oauth_signature_method";
static NSString *const DZOAuthHeaderTimestampKey		= @"oauth_timestamp";
static NSString *const DZOAuthHeaderNonceKey			= @"oauth_nonce";
static NSString *const DZOAuthHeaderSignatureKey		= @"oauth_signature";
static NSString *const DZOAuthHeaderVerifierKey			= @"oauth_verifier";
static NSString *const DZOAuthHeaderConsumerKey			= @"oauth_consumer_key";
static NSString *const DZOAuthHeaderTokenKey			= @"oauth_token";

static inline NSString *NSStringFromSignatureMethod(DZOAuthSignatureMethod method) {
	NSString *value = nil;
	switch (method) {
		case DZOAuthSignatureMethodPlaintext:	value = @"PLAINTEXT"; break;
		case DZOAuthSignatureMethodHMAC_SHA1:	value = @"HMAC-SHA1"; break;
	}
	return value;
}

static NSString *DZOAuthSignature(NSString *base, DZOAuthSignatureMethod method, NSString *consumerSecret, NSString *tokenSecret) {
	NSString *ret = [NSString stringWithFormat:@"%@&%@", consumerSecret ?: @"", tokenSecret ?: @""];

	switch (method) {
		case DZOAuthSignatureMethodHMAC_SHA1: {
			const char *keyBytes = [ret UTF8String];
			const char *baseStringBytes = [base UTF8String];
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

			ret = [[NSString alloc] initWithData:mutableData encoding:NSUTF8StringEncoding];
			break;
		}

		default:
			break;
	}

	return ret;
}

@interface DZOAuth1Client ()

@property (nonatomic, strong) NSMutableDictionary *OAuthValues;
@property (nonatomic, copy) NSString *secret;

@end

@implementation DZOAuth1Client

- (void)sharedInit {
	if (!self.OAuthValues)
		self.OAuthValues = [NSMutableDictionary dictionary];

	self.OAuthValues[DZOAuthHeaderVersionKey] = DZOAuth1Version;
	self.OAuthValues[DZOAuthHeaderSignatureMethodKey] = NSStringFromSignatureMethod([[self class] signatureMethod]);
	self.OAuthValues[DZOAuthHeaderConsumerKey] = [[self class] consumerKey];
}

- (id)initWithBaseURL:(NSURL *)URL credential:(DZOAuth1Credential *)credential {
    if ((self = [super initWithBaseURL: URL])) {
        self.credential = credential;
		[self sharedInit];
    }
    return self;
}

- (id)initWithBaseURL:(NSURL *)url {
	if ((self = [super initWithBaseURL:url])) {
		[self sharedInit];
	}
	return self;
}

#pragma mark - Properties

- (void)setCredential:(DZOAuth1Credential *)credential {
    if (credential == _credential)
        return;

	if (!self.OAuthValues)
		self.OAuthValues = [NSMutableDictionary dictionary];

    _credential = credential;
	self.OAuthValues[DZOAuthHeaderTokenKey] = credential.token;
	self.OAuthValues[DZOAuthHeaderVerifierKey] = credential.verifier ?: @"";
    self.secret = credential.secret;
}

#pragma mark - Request Signing

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
	request.timeoutInterval = 20;
	request.HTTPShouldHandleCookies = NO;
	
	NSMutableDictionary *headers = [self.OAuthValues mutableCopy];
	
    // Generate timestamp
	headers[DZOAuthHeaderTimestampKey] = [NSString stringWithFormat:@"%d", (NSUInteger)[[NSDate date] timeIntervalSince1970]];
	
	// Generate nonce
	CFUUIDRef UUID = CFUUIDCreate(NULL);
	headers[DZOAuthHeaderNonceKey] = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
	CFRelease(UUID);
	
	// Filter out empty headers
	[headers removeObjectsForKeys: [[headers keysOfEntriesPassingTest:^BOOL(id key, NSString *obj, BOOL *stop) {
		return !obj.length;
	}] allObjects]];

    // Add parameters from the query string
	NSArray *pairs = [request.URL.query componentsSeparatedByString:@"&"];
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:pairs.count];
    [pairs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray *elements = [obj componentsSeparatedByString:@"="];
        NSString *key = elements[0];
        NSString *value = elements.count > 1 ? elements[1] : @"";
		query[key] = value;
    }];
	[query addEntriesFromDictionary: headers];
	
	// Add parameters from the request body
    // Only if we're POSTing, GET parameters were already added
    if ([request.HTTPMethod.uppercaseString isEqualToString:@"POST"])
        [query addEntriesFromDictionary:parameters];
	
	NSString *parameterString = AFQueryStringFromParametersWithEncoding(query, NSUTF8StringEncoding);
	
	// Get the base URL String (with no parameters)
    NSArray *URLParts = [request.URL.absoluteString componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"?#"]];
    NSString *URLBase = [URLParts[0] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	
	NSString *baseString = [NSString stringWithFormat:@"%@&%@&%@", request.HTTPMethod.uppercaseString, URLBase, parameterString];
	headers[DZOAuthHeaderSignatureKey] = DZOAuthSignature(baseString, [[self class] signatureMethod], [[self class] consumerSecret], self.secret);
	
	NSString *oauthString = [@"OAuth " stringByAppendingString:  AFQueryStringFromParametersWithEncoding(headers, NSUTF8StringEncoding)];
	[request setValue: oauthString forHTTPHeaderField: @"Authorization"];
	
	return request;
}

- (NSMutableURLRequest *)xAuthRequestForURL:(NSURL *)endpoint username:(NSString *)username password:(NSString *)password {
	return [self requestWithMethod:@"POST" path:endpoint.absoluteString parameters: @{
        @"x_auth_mode" : @"client_auth",
        @"x_auth_username" : username,
        @"x_auth_password" : password
    }];
}

#pragma mark - Concrete methods

static NSString *const DZOAuthSubclassMethod = @"DZOAuthSubclassMethod";

+ (DZOAuthSignatureMethod)signatureMethod {
    return DZOAuthSignatureMethodPlaintext;
}

+ (NSString *)consumerKey {
    DZConcreteImplementation([DZOAuth1Client class]);
    return nil;
}

+ (NSString *)consumerSecret {
    DZConcreteImplementation([DZOAuth1Client class]);
    return nil;
}

+ (NSURL *)requestTokenURL {
    DZConcreteImplementation([DZOAuth1Client class]);
    return nil;
}

+ (NSURL *)authorizationURL {
    DZConcreteImplementation([DZOAuth1Client class]);
    return nil;
}

+ (NSURL *)accessTokenURL {
    DZConcreteImplementation([DZOAuth1Client class]);
    return nil;
}

@end
