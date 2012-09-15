//
//  DZDropboxClient.m
//  Markable
//
//  Created by Zachary Waldowski on 3/6/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxClient.h"
#import "AFJSONRequestOperation.h"
#import "DZDropboxAccountInfo.h"
#import "DZDropboxMetadata.h"
#import "DZDropboxDeltaEntry.h"
#import "DZOAuth1Credential.h"

static NSString *const DZDropboxClientRootName[] = {
    @"dropbox",
    @"sandbox",
};

NSString *DZDropboxAPIHost = @"api.dropbox.com";
NSString *DZDropboxAPIContentHost = @"api-content.dropbox.com";
NSString *DZDropboxAPIVersion = @"1";
NSString *DZDropboxWebHost = @"www.dropbox.com";
NSString *DZDropboxProtocol = @"dbapi-1";
NSString *DZDropboxSavedCredentialsKey = @"DZDropboxDropboxSavedCredentials";
NSString *DZDropboxUnknownUserID = @"unknown";

static inline NSString *NSStringFromThumbnailSize(DZDropboxThumbnailSize size){
	NSString *value = nil;
	switch (size) {
		case DZDropboxThumbnailSizeSmall:  value = @"small";  break;
		case DZDropboxThumbnailSizeMedium: value = @"medium"; break;
		case DZDropboxThumbnailSizeLarge:  value = @"large";  break;
	}
	return value;
}

static NSString *DZDropboxUserAgent(void) {
	static dispatch_once_t onceToken;
	static NSString *userAgent = nil;
	dispatch_once(&onceToken, ^{
		NSBundle *bundle = [NSBundle mainBundle];
        NSString *appName = [[bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        userAgent = [[NSString alloc] initWithFormat:@"%@/%@", appName, appVersion];
	});
	return userAgent;
}

static NSString *DZDropboxBestLanguage(void) {
	static dispatch_once_t onceToken;
	static NSString *preferredLang = nil;
	dispatch_once(&onceToken, ^{
		NSString *lang = [[NSLocale preferredLanguages] objectAtIndex:0];
        if ([[[NSBundle mainBundle] localizations] containsObject:lang])
            preferredLang = [lang copy];
        else
            preferredLang = @"en";
	});
    return preferredLang;
}

extern NSDictionary * DZParametersFromURLQuery(NSURL *URL);

NSDictionary * DZParametersFromURLQuery(NSURL *URL) {
	NSString *queryString = URL.query;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (queryString) {
        NSScanner *parameterScanner = [[NSScanner alloc] initWithString:queryString];
        NSString *name = nil;
        NSString *value = nil;
        
        while (![parameterScanner isAtEnd]) {
            name = nil;        
            [parameterScanner scanUpToString:@"=" intoString:&name];
            [parameterScanner scanString:@"=" intoString:NULL];
            
            value = nil;
            [parameterScanner scanUpToString:@"&" intoString:&value];
            [parameterScanner scanString:@"&" intoString:NULL];		
            
            if (name && value) {
                [parameters setValue:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:[name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
    
    return parameters;
}

#pragma mark -

@implementation DZDropboxClient {
	NSURL *_contentBaseURL;
}

#pragma mark Init

- (id)initWithUserID:(NSString *)userID {
	NSString *URLString = [NSString stringWithFormat:@"https://%@/%@/", DZDropboxAPIHost, DZDropboxAPIVersion];
    NSString *contentURLString = [NSString stringWithFormat:@"https://%@/%@/", DZDropboxAPIContentHost, DZDropboxAPIVersion];
    DZOAuth1Credential *credential = nil;
    
    if (userID.length && ![userID isEqualToString: DZDropboxUnknownUserID]) {
        NSDictionary *credentialStores = [[NSUserDefaults standardUserDefaults] objectForKey:DZDropboxSavedCredentialsKey];
        NSData *credentialData = credentialStores ? [credentialStores objectForKey:userID] : nil;
        if (credentialData.length)
            credential = [NSKeyedUnarchiver unarchiveObjectWithData: credentialData];
    }
    
    if ((self = [super initWithBaseURL: [NSURL URLWithString:URLString] credential: credential])) {
		_userID = userID.length ? [userID copy] : DZDropboxUnknownUserID;
		_contentBaseURL = [NSURL URLWithString:contentURLString];
		
		[self setDefaultHeader:@"User-Agent" value:DZDropboxUserAgent()];
		[self setDefaultHeader:@"Locale" value:DZDropboxBestLanguage()];
		
		[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        
    }
    return self;
}

- (instancetype)init {
	return [self initWithUserID: DZDropboxUnknownUserID];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	return [self initWithUserID:[aDecoder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_userID];
}

#pragma mark URL request factory

- (NSMutableURLRequest *)contentRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	NSMutableURLRequest *orig = [self requestWithMethod:method path:path parameters:parameters];
	orig.URL = [NSURL URLWithString:path relativeToURL:_contentBaseURL];
	return orig;
}

#pragma mark Loading methods

- (void)loadAccountInfoWithSuccess:(void(^)(DZDropboxAccountInfo *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(success);
	
	[self getPath:@"account/info" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		DZDropboxAccountInfo* accountInfo = [[DZDropboxAccountInfo alloc] initWithDictionary:responseObject];
		success(accountInfo);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)loadMetadata:(NSString *)path parameters:(NSDictionary *)params success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSString* fullPath = [NSString stringWithFormat:@"metadata/%@%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success(operation.response.statusCode == 304 ? nil : [[DZDropboxMetadata alloc] initWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)loadMetadata:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	[self loadMetadata:path parameters:nil success:success failure:failure];
}

- (void)loadMetadata:(NSString *)path hash:(NSString *)hash success:(DBResultBlock)success failure:(DBErrorBlock)failure {
    NSDictionary *params = hash ? [NSDictionary dictionaryWithObject:hash forKey:@"hash"] : nil;
	[self loadMetadata:path parameters:params success:success failure:failure];
}

- (void)loadMetadata:(NSString *)path revision:(NSString *)rev success:(DBResultBlock)success failure:(DBErrorBlock)failure {
    NSDictionary *params = rev ? [NSDictionary dictionaryWithObject:rev forKey:@"rev"] : nil;
	[self loadMetadata:path parameters:params success:success failure:failure];
}

- (void)loadDelta:(NSString *)sinceCursor success:(void(^)(NSArray *entries, BOOL shouldReset, NSString *cursor, BOOL hasMore))success failure:(DBErrorBlock)failure {
	NSParameterAssert(success);
	
	NSDictionary *params = sinceCursor ? [NSDictionary dictionaryWithObject:sinceCursor forKey:@"cursor"] : nil;
	[self postPath:@"delta" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		NSArray *entryObjects = responseObject[@"entries"];
		NSMutableArray *entries = [NSMutableArray arrayWithCapacity: entryObjects.count];
		for (NSArray *obj in entryObjects) {
			[entries addObject: [[DZDropboxDeltaEntry alloc] initWithArray:obj]];
		}

        BOOL shouldReset = [responseObject[@"reset"] boolValue];
        NSString *cursor = responseObject[@"cursor"];
        BOOL hasMore = [responseObject[@"has_more"] boolValue];
		
		success([entries copy], shouldReset, cursor, hasMore);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)downloadFile:(NSString *)path revision:(NSString *)rev outputStream:(NSOutputStream *)stream success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSString* fullPath = [NSString stringWithFormat:@"files/%@%@", [[self class] dz_root], path];
	NSDictionary *params = rev ? [NSDictionary dictionaryWithObject:rev forKey:@"rev"] : nil;
	NSURLRequest *request = [self contentRequestWithMethod:@"GET" path:fullPath parameters:params];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSData *metadataObj = [[operation.response.allHeaderFields objectForKey:@"X-Dropbox-Metadata"] dataUsingEncoding:NSUTF8StringEncoding];
		NSDictionary *metadataDict = [NSJSONSerialization JSONObjectWithData:metadataObj options:0 error:NULL];
		success([[DZDropboxMetadata alloc] initWithDictionary: metadataDict]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
	if (progress) {
		[operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
			progress((CGFloat)totalBytesRead/totalBytesExpectedToRead);
		}];
	}
	operation.outputStream = stream;
    [self enqueueHTTPRequestOperation:operation];
}

- (void)downloadFile:(NSString *)path toPath:(NSString *)destinationPath success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	[self downloadFile:path revision:nil toPath:destinationPath success:success progress:progress failure:failure];
}

- (void)downloadFile:(NSString *)path revision:(NSString *)rev toPath:(NSString *)destPath success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	NSParameterAssert(destPath.length);
	
	NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:destPath append:NO];
	[self downloadFile:path revision:rev outputStream:stream success:success progress:progress failure:failure];
}

- (void)downloadFile:(NSString *)path toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	[self downloadFile:path revision:nil toURL:destinationURL success:success progress:progress failure:failure];
}

- (void)downloadFile:(NSString *)path revision:(NSString *)rev toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(void(^)(CGFloat))progress failure:(DBErrorBlock)failure {
	NSParameterAssert(destinationURL);
	
	NSOutputStream *stream = [NSOutputStream outputStreamWithURL:destinationURL append:NO];
	[self downloadFile:path revision:rev outputStream:stream success:success progress:progress failure:failure];
}

- (void)downloadThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size outputStream:(NSOutputStream *)stream success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	
	NSString *fullPath = [NSString stringWithFormat:@"thumbnails/%@%@", [[self class] dz_root], path];
	NSString *format = (path.length > 4 && ([path hasSuffix:@"PNG"] || [path hasSuffix:@"png"] || [path hasSuffix:@"GIF"] || [path hasSuffix:@"gif"])) ? @"PNG" : @"JPEG";
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
							format, @"format",
							NSStringFromThumbnailSize(size), @"size",
							nil];
	NSURLRequest *request = [self contentRequestWithMethod:@"GET" path:fullPath parameters:params];
	
	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		NSData *metadataObj = [[operation.response.allHeaderFields objectForKey:@"X-Dropbox-Metadata"] dataUsingEncoding:NSUTF8StringEncoding];
		NSDictionary *metadataDict = [NSJSONSerialization JSONObjectWithData:metadataObj options:0 error:NULL];
		success([[DZDropboxMetadata alloc] initWithDictionary: metadataDict]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
	operation.outputStream = stream;
    [self enqueueHTTPRequestOperation:operation];
}

- (void)downloadThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size toPath:(NSString *)destinationPath success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(destinationPath.length);
	
	NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:destinationPath append:NO];
	[self downloadThumbnail:path size:size outputStream:stream success:success failure:failure];
}

- (void)downloadThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size toURL:(NSURL *)destinationURL success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(destinationURL);
	
	NSOutputStream *stream = [NSOutputStream outputStreamWithURL:destinationURL append:NO];
	[self downloadThumbnail:path size:size outputStream:stream success:success failure:failure];
}

- (void)uploadFileAtPath:(NSString *)filename toPath:(NSString *)remoteName overwrite:(BOOL)shouldOverwrite success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	NSParameterAssert(filename.length);
	NSParameterAssert(remoteName.length);
	
	BOOL isDir = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir];
    NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
	
    if (!fileExists || isDir || !fileAttrs) {
		if (failure) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  filename, @"sourcePath",
									  remoteName, @"destinationPath", nil];
			NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:isDir ? NSFileReadInvalidFileNameError : NSFileReadNoSuchFileError userInfo:userInfo];
			failure(error);
		}
        return;
    }
	
	NSString *fullPath = [NSString stringWithFormat:@"files_put/%@%@", [[self class] dz_root], remoteName];
	NSDictionary *params = [NSDictionary dictionaryWithObject:shouldOverwrite ? @"true" : @"false" forKey:@"overwrite"];
	NSMutableURLRequest *request = [self contentRequestWithMethod:@"PUT" path:fullPath parameters:params];
	NSString* contentLength = [NSString stringWithFormat: @"%qu", [fileAttrs fileSize]];
    [request addValue:contentLength forHTTPHeaderField: @"Content-Length"];
    [request addValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
        success([[DZDropboxMetadata alloc] initWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
	operation.inputStream = [NSInputStream inputStreamWithFileAtPath:filename];
	if (progress) {
		[operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
			progress((CGFloat)totalBytesWritten/totalBytesExpectedToWrite);
		}];
	}
	[self enqueueHTTPRequestOperation:operation];
}

- (void)uploadFileAtURL:(NSURL *)filename toPath:(NSString *)remoteName overwrite:(BOOL)shouldOverwrite success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	NSParameterAssert(filename);
	NSParameterAssert(remoteName.length);
	
	[self uploadFileAtPath:[filename path] toPath:remoteName overwrite:shouldOverwrite success:success progress:progress failure:failure];
}

- (void)loadRevisions:(NSString *)path success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	[self loadRevisions:path limit:10 success:success failure:failure];
}

- (void)loadRevisions:(NSString *)path limit:(NSInteger)limit success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSString *fullPath = [NSString stringWithFormat:@"revisions/%@%@", [[self class] dz_root], path];
	NSString *limitStr = [NSString stringWithFormat:@"%ld", limit];
    NSDictionary *params = [NSDictionary dictionaryWithObject:limitStr forKey:@"rev_limit"];
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
		if ([responseObject isKindOfClass:[NSDictionary class]])
			responseObject = [NSArray arrayWithObject:responseObject];

		NSMutableArray *revisions = [NSMutableArray arrayWithCapacity: responseObject.count];
		for (NSDictionary *obj in responseObject) {
			[revisions addObject: [[DZDropboxMetadata alloc] initWithDictionary:obj]];
		}
		
		success([revisions copy]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)restoreFile:(NSString *)path toRevision:(NSString *)revision success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
    
	NSString *fullPath = [NSString stringWithFormat:@"restore/%@%@", [[self class] dz_root], path];
    NSDictionary *params = [NSDictionary dictionaryWithObject:revision forKey:@"rev"];
	[self postPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		success([[DZDropboxMetadata alloc] initWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)searchFolder:(NSString *)path keyword:(NSString *)keyword success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSDictionary* params = [NSDictionary dictionaryWithObject:keyword forKey:@"query"];
	NSString* fullPath = [NSString stringWithFormat:@"search/%@%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
		if ([responseObject isKindOfClass:[NSDictionary class]])
			responseObject = @[responseObject];

		NSMutableArray *results = [NSMutableArray arrayWithCapacity: responseObject.count];
		for (NSDictionary *obj in responseObject) {
			[results addObject: [[DZDropboxMetadata alloc] initWithDictionary:obj]];
		}
		
		success([results copy]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)createFolderAtPath:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							[[self class] dz_root], @"root",
							path, @"path", nil];
	[self postPath:@"fileops/create_folder" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		success([[DZDropboxMetadata alloc] initWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)deleteItemAtPath:(NSString *)path success:(DBBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path);
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							[[self class] dz_root], @"root",
							path, @"path", nil];
	[self postPath:@"fileops/delete" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success();
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)copyPath:(NSString *)from toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(from.length);
	NSParameterAssert(to.length);
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							[[self class] dz_root], @"root",
							from, @"from_path",
							to, @"to_path", nil];
	[self postPath:@"fileops/copy" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		success([[DZDropboxMetadata alloc] initWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)movePath:(NSString *)from toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(from.length);
	NSParameterAssert(to.length);
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							[[self class] dz_root], @"root",
							from, @"from_path",
							to, @"to_path", nil];
	[self postPath:@"fileops/move" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		success([[DZDropboxMetadata alloc] initWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)createCopyRef:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSDictionary *params = [NSDictionary dictionaryWithObject:path forKey:@"path"];
    NSString *fullPath = [NSString stringWithFormat:@"copy_ref/%@%@", [[self class] dz_root], path];
	[self postPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success([responseObject objectForKey:@"copy_ref"]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)copyRef:(NSString *)fromRef toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(fromRef.length);
	NSParameterAssert(to.length);
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							[[self class] dz_root], @"root",
							fromRef, @"from_copy_ref",
							to, @"to_path", nil];
	[self postPath:@"fileops/copy" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (!success)
			return;
		
		success([[DZDropboxMetadata alloc] initWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)getSharableLinkForFile:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSString* fullPath = [NSString stringWithFormat:@"shares/%@%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success([responseObject objectForKey:@"url"]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (error)
			failure(error);
	}];
}

- (void)getStreamableURLForFile:(NSString *)path success:(void(^)(NSURL *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSString* fullPath = [NSString stringWithFormat:@"media/%@%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success([NSURL URLWithString:[responseObject objectForKey:@"url"]]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (error)
			failure(error);
	}];
}

#pragma mark Cancellation

- (void)cancelDownloadingFile:(NSString *)path {
	[self cancelAllHTTPOperationsWithMethod:@"GET" path:path];
}

- (void)cancelDownloadingThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size {
	NSString *method = @"GET";
	NSString *sizeValue = NSStringFromThumbnailSize(size);
	NSIndexSet *matches = [self.operationQueue.operations indexesOfObjectsPassingTest:^BOOL(NSOperation *operation, NSUInteger idx, BOOL *stop) {
		if ([operation isKindOfClass:[AFHTTPRequestOperation class]] && (!method || [method isEqualToString:[[(AFHTTPRequestOperation *)operation request] HTTPMethod]]) && [path isEqualToString:[[[(AFHTTPRequestOperation *)operation request] URL] path]]) {
			NSURL *requestURL = [[(AFHTTPRequestOperation *)operation request] URL];
			return [[DZParametersFromURLQuery(requestURL) objectForKey:@"size"] isEqualToString:sizeValue];
		}
		return NO;
	}];
	[[self.operationQueue.operations objectsAtIndexes: matches] makeObjectsPerformSelector: @selector(cancel)];
}

- (void)cancelUploadingFile:(NSString *)path {
	[self cancelAllHTTPOperationsWithMethod:@"POST" path:path];
}

#pragma mark Internal

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest 
                                                    success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                    failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
	return [super HTTPRequestOperationWithRequest:urlRequest success:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (operation.response.statusCode == 401 && self.authenticationFailureBlock)
			self.authenticationFailureBlock(self.userID);
		else if (failure)
			failure(operation, error);
	}];
}


#pragma mark Linking

- (BOOL)isLinked {
	return (self.userID.length && ![self.userID isEqualToString: DZDropboxUnknownUserID]);
}

- (void)dz_setUserID:(NSString *)userID {
	NSParameterAssert(userID.length);
    
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *credentialStores = [[sud objectForKey:DZDropboxSavedCredentialsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    
    [credentialStores removeObjectForKey:_userID];
    
    _userID = [userID copy];
	
	if (!self.credential)
		[credentialStores removeObjectForKey:userID];
	else
		[credentialStores setObject: [NSKeyedArchiver archivedDataWithRootObject: self.credential] forKey:userID];
	
	[sud setObject:credentialStores forKey:DZDropboxSavedCredentialsKey];
	[sud synchronize];
}

- (void)dz_resetCredential {
	[self.credential evict];
    [self dz_setUserID:nil];
}

+ (NSString *)dz_root {
    return DZDropboxClientRootName[[self clientRoot]];
}

+ (NSArray *)linkedUserIDs {
	NSDictionary *credentialStore = [[NSUserDefaults standardUserDefaults] objectForKey:DZDropboxSavedCredentialsKey];
	
	if (!credentialStore.count)
		return nil;
    
	return [[credentialStore allKeys] copy];
}

+ (void)unlinkAll {
	NSDictionary *credentialStore = [[NSUserDefaults standardUserDefaults] objectForKey:DZDropboxSavedCredentialsKey];
	if (credentialStore.count) {
        [credentialStore enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString *userID, NSData *obj, BOOL *stop) {
            DZOAuth1Credential *credential = [NSKeyedUnarchiver unarchiveObjectWithData: obj];
			[credential evict];
        }];
    }
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:DZDropboxSavedCredentialsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (DZDropboxClientRoot)clientRoot {
    return DZDropboxClientRootDropbox;
}

@end