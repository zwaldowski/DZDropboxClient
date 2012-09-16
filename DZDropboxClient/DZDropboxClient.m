//
//  DZDropboxClient.m
//  DZDropboxClient
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

NSString *DZDropboxAPIHost = @"api.dropbox.com";
NSString *DZDropboxAPIContentHost = @"api-content.dropbox.com";
NSString *DZDropboxAPIVersion = @"1";
NSString *DZDropboxWebHost = @"www.dropbox.com";
NSString *DZDropboxProtocol = @"dbapi-1";
NSString *DZDropboxSavedCredentialsKey = @"DZDropboxDropboxSavedCredentials";
NSString *DZDropboxUnknownUserID = @"unknown";

static inline NSString *NSStringFromClientRoot(DZDropboxClientRoot root){
	NSString *value = nil;
	switch (root) {
		case DZDropboxClientRootDropbox:	value = @"dropbox"; break;
		case DZDropboxClientRootAppFolder:	value = @"sandbox"; break;
	}
	return value;
}

static inline NSString *NSStringFromThumbnailSize(DZDropboxThumbnailSize size){
	NSString *value = nil;
	switch (size) {
		case DZDropboxThumbnailSizeSmall:  value = @"small";  break;
		case DZDropboxThumbnailSizeMedium: value = @"medium"; break;
		case DZDropboxThumbnailSizeLarge:  value = @"large";  break;
	}
	return value;
}

extern NSDictionary *DZParametersFromURLQuery(NSURL *URL);

NSDictionary *DZParametersFromURLQuery(NSURL *URL) {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (URL.query.length) {
        NSScanner *parameterScanner = [[NSScanner alloc] initWithString: URL.query];
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
	NSString *_contentBase;
}

#pragma mark Init

- (id)initWithUserID:(NSString *)userID {
	NSURL *baseURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://%@/%@/", DZDropboxAPIHost, DZDropboxAPIVersion]];
    NSString *contentBaseURL = [NSString stringWithFormat:@"https://%@/%@/", DZDropboxAPIContentHost, DZDropboxAPIVersion];
    DZOAuth1Credential *credential = nil;
    
    if (userID.length && ![userID isEqualToString: DZDropboxUnknownUserID]) {
        NSDictionary *credentialStores = [[NSUserDefaults standardUserDefaults] objectForKey:DZDropboxSavedCredentialsKey];
        NSData *credentialData = credentialStores ? credentialStores[userID] : nil;
        if (credentialData.length)
            credential = [NSKeyedUnarchiver unarchiveObjectWithData: credentialData];
    }
    
    if ((self = [super initWithBaseURL: baseURL credential: credential])) {
		_userID = userID.length ? [userID copy] : DZDropboxUnknownUserID;
		_contentBase = contentBaseURL;

		static dispatch_once_t onceToken;
		static NSString *userAgent = nil;
		static NSString *preferredLang = nil;
		dispatch_once(&onceToken, ^{
			NSBundle *bundle = [NSBundle mainBundle];
			NSString *appName = [[bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@" " withString:@""];
			NSString *appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			userAgent = [[NSString alloc] initWithFormat:@"%@/%@", appName, appVersion];

			NSString *lang = [NSLocale preferredLanguages][0];
			if ([[[NSBundle mainBundle] localizations] containsObject:lang])
				preferredLang = [lang copy];
			else
				preferredLang = @"en";
		});

		[self setDefaultHeader:@"User-Agent" value: userAgent];
		[self setDefaultHeader:@"Locale" value: preferredLang];
		
		[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        
    }
    return self;
}

- (instancetype)init {
	return [self initWithUserID: DZDropboxUnknownUserID];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	return [self initWithUserID: [aDecoder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject: _userID];
}

#pragma mark URL request factory

- (NSMutableURLRequest *)contentRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	return [self requestWithMethod: method path: [_contentBase stringByAppendingString: path] parameters: parameters];
}

#pragma mark Loading methods

- (void)loadAccountInfoWithSuccess:(void(^)(DZDropboxAccountInfo *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(success);
	
	[self getPath:@"account/info" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success([DZDropboxAccountInfo accountInfoWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)loadMetadata:(NSString *)path parameters:(NSDictionary *)params success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSString* fullPath = [NSString stringWithFormat:@"metadata/%@/%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success(operation.response.statusCode == 304 ? nil : [DZDropboxMetadata metadataWithDictionary:responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)loadMetadata:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	[self loadMetadata:path parameters:nil success:success failure:failure];
}

- (void)loadMetadata:(NSString *)path hash:(NSString *)hash success:(DBResultBlock)success failure:(DBErrorBlock)failure {
    NSDictionary *params = hash ? @{@"hash": hash} : nil;
	[self loadMetadata:path parameters:params success:success failure:failure];
}

- (void)loadMetadata:(NSString *)path revision:(NSString *)rev success:(DBResultBlock)success failure:(DBErrorBlock)failure {
    NSDictionary *params = rev ? @{@"rev": rev} : nil;
	[self loadMetadata:path parameters:params success:success failure:failure];
}

- (void)loadDelta:(NSString *)sinceCursor success:(void(^)(NSArray *entries, BOOL shouldReset, NSString *cursor, BOOL hasMore))success failure:(DBErrorBlock)failure {
	NSParameterAssert(success);
	
	NSDictionary *params = sinceCursor ? @{@"cursor": sinceCursor} : nil;
	[self postPath:@"delta" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		NSArray *entryObjects = responseObject[@"entries"];
		NSMutableArray *entries = [NSMutableArray arrayWithCapacity: entryObjects.count];
		for (NSArray *obj in entryObjects) {
			[entries addObject: [DZDropboxDeltaEntry deltaEntryWithContents: obj]];
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

	NSString* fullPath = [NSString stringWithFormat:@"files/%@/%@", [[self class] dz_root], path];
	NSDictionary *params = rev ? @{@"rev": rev} : nil;
	NSURLRequest *request = [self contentRequestWithMethod:@"GET" path:fullPath parameters:params];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSData *metadataObj = [(operation.response.allHeaderFields)[@"X-Dropbox-Metadata"] dataUsingEncoding:NSUTF8StringEncoding];
		NSDictionary *metadataDict = [NSJSONSerialization JSONObjectWithData:metadataObj options:0 error:NULL];
		success([DZDropboxMetadata metadataWithDictionary: metadataDict]);
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

- (void)downloadFile:(NSString *)path toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	[self downloadFile:path revision:nil toURL:destinationURL success:success progress:progress failure:failure];
}

- (void)downloadFile:(NSString *)path revision:(NSString *)rev toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(void(^)(CGFloat))progress failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(destinationURL);

	NSString* fullPath = [NSString stringWithFormat:@"files/%@/%@", [[self class] dz_root], path];
	NSDictionary *params = rev ? @{@"rev": rev} : nil;
	NSURLRequest *request = [self contentRequestWithMethod:@"GET" path:fullPath parameters:params];
	
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success) {
			NSData *metadataObj = [operation.response.allHeaderFields[@"X-Dropbox-Metadata"] dataUsingEncoding: NSUTF8StringEncoding];
			NSDictionary *metadataDict = [NSJSONSerialization JSONObjectWithData:metadataObj options:0 error:NULL];
			success([DZDropboxMetadata metadataWithDictionary: metadataDict]);
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
	if (progress) {
		[operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
			progress((CGFloat)totalBytesRead/totalBytesExpectedToRead);
		}];
	}
	operation.outputStream = [NSOutputStream outputStreamWithURL:destinationURL append:NO];
	
    [self enqueueHTTPRequestOperation: operation];
}

- (void)downloadThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size toURL:(NSURL *)destinationURL success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(destinationURL);

	NSString *fullPath = [NSString stringWithFormat:@"thumbnails/%@/%@", [[self class] dz_root], path];
	NSString *format = ([path.lowercaseString hasSuffix: @"png"] || [path.lowercaseString hasSuffix: @"gif"]) ? @"PNG" : @"JPEG";
	NSURLRequest *request = [self contentRequestWithMethod:@"GET" path: fullPath parameters: @{
							 @"format" : format,
							 @"size" : NSStringFromThumbnailSize(size)
							 }];

	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success) {
			NSData *metadataObj = [operation.response.allHeaderFields[@"X-Dropbox-Metadata"] dataUsingEncoding: NSUTF8StringEncoding];
			NSDictionary *metadataDict = [NSJSONSerialization JSONObjectWithData:metadataObj options:0 error:NULL];
			success([DZDropboxMetadata metadataWithDictionary: metadataDict]);
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
	operation.outputStream = [NSOutputStream outputStreamWithURL:destinationURL append:NO];

    [self enqueueHTTPRequestOperation:operation];
}

- (void)uploadFileAtURL:(NSURL *)filename toPath:(NSString *)remoteName overwrite:(BOOL)shouldOverwrite success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure {
	NSParameterAssert(filename);
	NSParameterAssert(remoteName.length);

	NSError *error = nil;

	unsigned long long size = ULLONG_MAX;
	BOOL fileExists = YES;
	BOOL isDir = NO;

    NSNumber *fileSize = nil;
	BOOL result = [filename getResourceValue: &fileSize forKey: NSURLFileSizeKey error: &error];
	if (!result && !error) { // Below iOS 5
		NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath: filename.path error: &error];
		if (!attr.count || error) {
			size = 0;
			fileExists = NO;
		} else {
			size = [attr[NSFileSize] unsignedLongLongValue];
			isDir = [attr[NSFileType] isEqualToString: NSFileTypeDirectory];
		}
	} else if (error) { // iOS 5+, but failure
		fileExists = NO;
		size = 0;
	} else { // iOS 5
		size = [fileSize unsignedLongLongValue];

		NSNumber *isDirValue = nil;
		[filename getResourceValue: &isDirValue forKey: NSURLIsDirectoryKey error: &error];
		isDir = [isDirValue boolValue];
	}

	
    if (!fileExists || isDir) {
		if (failure) {
			if (!error) {
				error = [NSError errorWithDomain: NSCocoaErrorDomain code: isDir ? NSFileReadInvalidFileNameError : NSFileReadNoSuchFileError userInfo: @{
							 NSFilePathErrorKey : filename.path
						 }];
			}
			failure(error);
		}
        return;
    }

	NSString *fullPath = [NSString stringWithFormat :@"files_put/%@/%@", [[self class] dz_root], remoteName];
	NSDictionary *params = @{@"overwrite": shouldOverwrite ? @"true" : @"false"};
	NSMutableURLRequest *request = [self contentRequestWithMethod: @"PUT" path: fullPath parameters: params];
    [request addValue: [NSString stringWithFormat: @"%qu", size] forHTTPHeaderField: @"Content-Length"];
    [request addValue: @"application/octet-stream" forHTTPHeaderField: @"Content-Type"];
	
	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];

	operation.inputStream = [NSInputStream inputStreamWithURL: filename];
	if (progress)
		[operation setUploadProgressBlock:^(NSUInteger written, long long totalWritten, long long totalExpected) {
			progress((CGFloat)totalWritten/totalExpected);
		}];
	
	[self enqueueHTTPRequestOperation:operation];
}

- (void)loadRevisions:(NSString *)path success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	[self loadRevisions:path limit:10 success:success failure:failure];
}

- (void)loadRevisions:(NSString *)path limit:(NSUInteger)limit success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSString *fullPath = [NSString stringWithFormat:@"revisions/%@/%@", [[self class] dz_root], path];
	NSString *limitStr = [NSString stringWithFormat:@"%d", limit];
    NSDictionary *params = @{@"rev_limit": limitStr};
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
		if ([responseObject isKindOfClass:[NSDictionary class]])
			responseObject = @[responseObject];

		NSMutableArray *revisions = [NSMutableArray arrayWithCapacity: responseObject.count];
		for (NSDictionary *obj in responseObject) {
			[revisions addObject: [DZDropboxMetadata metadataWithDictionary: obj]];
		}
		
		success([revisions copy]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)restoreFile:(NSString *)path toRevision:(NSString *)revision success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
    
	NSString *fullPath = [NSString stringWithFormat:@"restore/%@/%@", [[self class] dz_root], path];
    NSDictionary *params = @{@"rev": revision};
	[self postPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)searchFolder:(NSString *)path keyword:(NSString *)keyword success:(DBResultsBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSDictionary* params = @{@"query": keyword};
	NSString* fullPath = [NSString stringWithFormat:@"search/%@/%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
		if ([responseObject isKindOfClass:[NSDictionary class]])
			responseObject = @[responseObject];

		NSMutableArray *results = [NSMutableArray arrayWithCapacity: responseObject.count];
		for (NSDictionary *obj in responseObject) {
			[results addObject: [DZDropboxMetadata metadataWithDictionary:obj]];
		}
		
		success([results copy]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)createFolderAtPath:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	
	NSDictionary* params = @{@"root": [[self class] dz_root],
							@"path": path};
	[self postPath:@"fileops/create_folder" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)deleteItemAtPath:(NSString *)path success:(DBBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(path);
	
	NSDictionary* params = @{@"root": [[self class] dz_root],
							@"path": path};
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
	
	NSDictionary* params = @{@"root": [[self class] dz_root],
							@"from_path": from,
							@"to_path": to};
	[self postPath:@"fileops/copy" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)movePath:(NSString *)from toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(from.length);
	NSParameterAssert(to.length);
	
	NSDictionary* params = @{@"root": [[self class] dz_root],
							@"from_path": from,
							@"to_path": to};
	[self postPath:@"fileops/move" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)createCopyRef:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);
	
	NSDictionary *params = @{@"path": path};
    NSString *fullPath = [NSString stringWithFormat:@"copy_ref/%@/%@", [[self class] dz_root], path];
	[self postPath:fullPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success(responseObject[@"copy_ref"]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)copyRef:(NSString *)fromRef toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure {
	NSParameterAssert(fromRef.length);
	NSParameterAssert(to.length);
	
	NSDictionary* params = @{@"root": [[self class] dz_root],
							@"from_copy_ref": fromRef,
							@"to_path": to};
	[self postPath:@"fileops/copy" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if (success)
			success([DZDropboxMetadata metadataWithDictionary: responseObject]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (failure)
			failure(error);
	}];
}

- (void)getSharableLinkForFile:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSString* fullPath = [NSString stringWithFormat:@"shares/%@/%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success(responseObject[@"url"]);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (error)
			failure(error);
	}];
}

- (void)getStreamableURLForFile:(NSString *)path success:(void(^)(NSURL *))success failure:(DBErrorBlock)failure {
	NSParameterAssert(path.length);
	NSParameterAssert(success);

	NSString* fullPath = [NSString stringWithFormat:@"media/%@/%@", [[self class] dz_root], path];
	[self getPath:fullPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		success([NSURL URLWithString:responseObject[@"url"]]);
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
			return [DZParametersFromURLQuery(requestURL)[@"size"] isEqualToString:sizeValue];
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
		credentialStores[userID] = [NSKeyedArchiver archivedDataWithRootObject: self.credential];
	
	[sud setObject:credentialStores forKey:DZDropboxSavedCredentialsKey];
	[sud synchronize];
}

- (void)dz_resetCredential {
	[self.credential evict];
    [self dz_setUserID:nil];
}

+ (NSString *)dz_root {
	return NSStringFromClientRoot([[self class] clientRoot]);
}

+ (NSArray *)linkedUserIDs {
	NSDictionary *credentialStore = [[NSUserDefaults standardUserDefaults] objectForKey:DZDropboxSavedCredentialsKey];
	
	if (!credentialStore.count)
		return nil;
    
	return [[credentialStore allKeys] copy];
}

+ (void)unlinkAll {
	NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
	NSDictionary *credentialStore = [sud objectForKey:DZDropboxSavedCredentialsKey];
	if (credentialStore.count) {
        [credentialStore enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString *userID, NSData *obj, BOOL *stop) {
            DZOAuth1Credential *credential = [NSKeyedUnarchiver unarchiveObjectWithData: obj];
			[credential evict];
        }];
    }
	[sud removeObjectForKey:DZDropboxSavedCredentialsKey];
    [sud synchronize];
}

+ (DZDropboxClientRoot)clientRoot {
    return DZDropboxClientRootDropbox;
}

@end