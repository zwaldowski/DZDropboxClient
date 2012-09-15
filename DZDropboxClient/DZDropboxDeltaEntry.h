//
//  DZDropboxDeltaEntry.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

@class DZDropboxMetadata;

@interface DZDropboxDeltaEntry : NSObject <NSCoding>

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) DZDropboxMetadata *metadata;

+ (instancetype)deltaEntryWithContents:(id)contents;

@end
