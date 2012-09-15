//
//  DZDropboxClient.h
//  Markable
//
//  Created by Zachary Waldowski on 3/6/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZOAuth1Client.h"

@class DZDropboxMetadata, DZDropboxAccountInfo, DZDropboxDeltaEntry;

typedef void(^DBBlock)(void);
typedef void(^DBResultBlock)(DZDropboxMetadata *);
typedef void(^DBResultsBlock)(NSArray *);
typedef void(^DBProgressBlock)(CGFloat);
typedef void(^DBErrorBlock)(NSError *);

typedef enum {
	DZDropboxThumbnailSizeSmall,
	DZDropboxThumbnailSizeMedium,
	DZDropboxThumbnailSizeLarge
} DZDropboxThumbnailSize;

typedef enum {
    DZDropboxClientRootDropbox = 0,
    DZDropboxClientRootAppFolder = 1
} DZDropboxClientRoot;

@interface DZDropboxClient : DZOAuth1Client <NSCoding>

+ (DZDropboxClientRoot)clientRoot; 

- (id)initWithUserID:(NSString *)userID;

+ (NSArray *)linkedUserIDs;
+ (void)unlinkAll;

@property (nonatomic, readonly) NSString *userID;
@property (nonatomic, readonly, getter = isLinked) BOOL linked;

@property (nonatomic, copy) void(^authenticationFailureBlock)(NSString *userID);

- (NSMutableURLRequest *)contentRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;

- (void)loadAccountInfoWithSuccess:(void(^)(DZDropboxAccountInfo *))success failure:(DBErrorBlock)failure;

- (void)loadMetadata:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure;
- (void)loadMetadata:(NSString *)path hash:(NSString *)hash success:(DBResultBlock)success failure:(DBErrorBlock)failure;
- (void)loadMetadata:(NSString *)path revision:(NSString *)rev success:(DBResultBlock)success failure:(DBErrorBlock)failure;

- (void)loadDelta:(NSString *)sinceCursor success:(void(^)(NSArray *entries, BOOL shouldReset, NSString *cursor, BOOL hasMore))success failure:(DBErrorBlock)failure;

- (void)downloadFile:(NSString *)path toPath:(NSString *)destinationPath success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;
- (void)downloadFile:(NSString *)path revision:(NSString *)rev toPath:(NSString *)destPath success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;

- (void)downloadFile:(NSString *)path toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;
- (void)downloadFile:(NSString *)path revision:(NSString *)rev toURL:(NSURL *)destinationURL success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;

- (void)downloadThumbnail:(NSString *)forPath size:(DZDropboxThumbnailSize)size toPath:(NSString *)destinationPath success:(DBResultBlock)success failure:(DBErrorBlock)failure;
- (void)downloadThumbnail:(NSString *)forPath size:(DZDropboxThumbnailSize)size toURL:(NSURL *)destinationURL success:(DBResultBlock)success failure:(DBErrorBlock)failure;

- (void)uploadFileAtPath:(NSString *)filename toPath:(NSString *)remoteName overwrite:(BOOL)shouldOverwrite success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;
- (void)uploadFileAtURL:(NSURL *)filename toPath:(NSString *)remoteName overwrite:(BOOL)shouldOverwrite success:(DBResultBlock)success progress:(DBProgressBlock)progress failure:(DBErrorBlock)failure;

- (void)loadRevisions:(NSString *)path success:(DBResultsBlock)success failure:(DBErrorBlock)failure;
- (void)loadRevisions:(NSString *)path limit:(NSInteger)limit  success:(DBResultsBlock)success failure:(DBErrorBlock)failure;

- (void)restoreFile:(NSString *)path toRevision:(NSString *)revision success:(DBResultBlock)success failure:(DBErrorBlock)failure;

- (void)searchFolder:(NSString *)path keyword:(NSString *)keyword success:(DBResultsBlock)success failure:(DBErrorBlock)failure;

- (void)createFolderAtPath:(NSString *)path success:(DBResultBlock)success failure:(DBErrorBlock)failure;
- (void)deleteItemAtPath:(NSString *)path success:(DBBlock)success failure:(DBErrorBlock)failure;

- (void)copyPath:(NSString *)from toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure;
- (void)movePath:(NSString *)from toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure;

- (void)createCopyRef:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure;
- (void)copyRef:(NSString *)fromRef toPath:(NSString *)to success:(DBResultBlock)success failure:(DBErrorBlock)failure;

- (void)getSharableLinkForFile:(NSString *)path success:(void(^)(NSString *))success failure:(DBErrorBlock)failure;
- (void)getStreamableURLForFile:(NSString *)path success:(void(^)(NSURL *))success failure:(DBErrorBlock)failure;

- (void)cancelDownloadingFile:(NSString *)path;
- (void)cancelDownloadingThumbnail:(NSString *)path size:(DZDropboxThumbnailSize)size;
- (void)cancelUploadingFile:(NSString *)path;

@end

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import "DZDropboxClient+iOS.h"
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#import "DZDropboxClient+OSX.h"
#endif
