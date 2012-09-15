//
//  DZAuthenticationStore.h
//  Markable
//
//  Created by Zachary Waldowski on 4/18/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

@protocol DZMutableAuthenticationStore

@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy, readwrite) id <NSObject, NSCoding> contents;
@property (nonatomic, copy, readwrite) NSDictionary *userInfo;

@end

@interface DZAuthenticationStore : NSObject <NSCoding, NSMutableCopying, NSCopying>

+ (id)storeForServiceName:(NSString *)name username:(NSString *)username contents:(id <NSObject, NSCoding>)contents userInfo:(NSDictionary *)userInfo;
+ (id)storeWithUsername:(NSString *)username contents:(id <NSObject, NSCoding>)contents userInfo:(NSDictionary *)userInfo;

@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, copy, readonly) id <NSObject, NSCoding> contents;
@property (nonatomic, copy, readonly) NSDictionary *userInfo;
@property (nonatomic, copy, readonly) NSString *serviceName;
@property (nonatomic, copy, readonly) NSString *identifier;

- (id)init NS_UNAVAILABLE;
- (id)initWithServiceName:(NSString *)service;

- (void)evict;

@end

@interface DZMutableAuthenticationStore : DZAuthenticationStore <DZMutableAuthenticationStore>

@end

@interface DZAuthenticationStore (DZAuthenticationStoreFactory)

+ (NSSet *)findStoresForService:(NSString *)service;
+ (instancetype)findStoreForServiceName:(NSString *)serviceName username:(NSString *)username;
+ (instancetype)findStoreForServiceName:(NSString *)serviceName identifier:(NSString *)unique;

@end