//
//  DZOAuth1Credential.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 4/18/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZAuthenticationStore.h"

@interface DZOAuth1Credential : DZAuthenticationStore

@property (nonatomic, copy, readonly) NSString *token;
@property (nonatomic, copy, readonly) NSString *secret;
@property (nonatomic, copy, readonly) NSString *verifier;

+ (id)storeForServiceName:(NSString *)name responseObject:(id)data username:(NSString *)username;

@end

@interface DZOMutableAuth1Credential : DZOAuth1Credential <DZMutableAuthenticationStore>

@property (nonatomic, copy, readwrite) NSString *token;
@property (nonatomic, copy, readwrite) NSString *secret;
@property (nonatomic, copy, readwrite) NSString *verifier;

@end