//
//  DZDropboxMetadata.h
//  Markable
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

@interface DZDropboxMetadata : NSObject <NSCoding>

- (id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic, readonly) BOOL thumbnailExists;
@property (nonatomic, readonly) long long totalBytes;
@property (nonatomic, readonly) NSDate* lastModifiedDate;
@property (nonatomic, readonly) NSDate* clientMTime;
@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly) NSArray* contents;
@property (nonatomic, readonly) NSString* hash;
@property (nonatomic, readonly) NSString* humanReadableSize;
@property (nonatomic, readonly) NSString* root;
@property (nonatomic, readonly) NSString* icon;
@property (nonatomic, readonly) long long revision;
@property (nonatomic, readonly) NSString* rev;
@property (nonatomic, readonly) BOOL isDeleted;
@property (nonatomic, readonly) NSString* filename;

@end
