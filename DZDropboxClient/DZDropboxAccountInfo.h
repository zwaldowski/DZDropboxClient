//
//  DZDropboxAccountInfo.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//


@interface DZDropboxAccountInfo : NSObject <NSCoding>

- (id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic, readonly) NSString *country;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *userID;
@property (nonatomic, readonly) NSString *referralLink;

@property (nonatomic, readonly) NSDictionary *quota;
@property (nonatomic, readonly) long long normalConsumedBytes;
@property (nonatomic, readonly) long long sharedConsumedBytes;
@property (nonatomic, readonly) long long totalConsumedBytes;
@property (nonatomic, readonly) long long totalBytes;

@end
