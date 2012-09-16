//
//  DZAuthenticationStore.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 4/18/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZAuthenticationStore.h"
#import <objc/runtime.h>

static NSString *const DZAuthenticationStoreUserDefaultsKey = @"DZAuthenticationStoreLibrary";

@interface DZAuthenticationStore ()

@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy, readwrite) id <NSCoding, NSObject> contents;
@property (nonatomic, copy, readwrite) NSDictionary *userInfo;
@property (nonatomic, copy, readwrite) NSString *serviceName;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSDictionary* baseQuery;

@end

@implementation DZAuthenticationStore

#pragma mark - Automatic KVC properties

static SEL getterForProperty(objc_property_t property)
{
	if (!property)
		return NULL;
	
	SEL getter = NULL;
    
	char *getterName = property_copyAttributeValue(property, "G");
	if (getterName)
		getter = sel_getUid(getterName);
	else
		getter = sel_getUid(property_getName(property));
	free(getterName);
	
	return getter;
}

static SEL setterForProperty(objc_property_t property)
{
	if (!property)
		return NULL;
	
	SEL setter = NULL;
    
	char *setterName = property_copyAttributeValue(property, "S");
	if (setterName)
		setter = sel_getUid(setterName);
	else {
		NSString *propertyName = @(property_getName(property));
		unichar firstChar = [propertyName characterAtIndex: 0];
		NSString *coda = [propertyName substringFromIndex: 1];
		setter = NSSelectorFromString([NSString stringWithFormat: @"set%c%@:", toupper(firstChar), coda]);
	}
	free(setterName);
	
	return setter;
}

static NSString *propertyNameForAccessor(Class cls, SEL selector) {
    if (!cls || !selector)
        return nil;
    
    NSString *propertyName = NSStringFromSelector(selector);
    if ([propertyName hasPrefix: @"set"])
    {
        unichar firstChar = [propertyName characterAtIndex: 3];
        NSString *coda = [propertyName substringWithRange: NSMakeRange(4, propertyName.length - 5)]; // -5 to remove trailing ':'
        propertyName = [NSString stringWithFormat: @"%c%@", tolower(firstChar), coda];
    }
    
    if (!class_getProperty(cls, propertyName.UTF8String))
    {
        // It's not a simple -xBlock/setXBlock: pair
        
        // If selector ends in ':', it's a setter.
        const BOOL isSetter = [NSStringFromSelector(selector) hasSuffix: @":"];
        const char *key = (isSetter ? "S" : "G");
        
        unsigned int i, count;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        
        for (i = 0; i < count; ++i)
        {
            objc_property_t property = properties[i];
            
            char *accessorName = property_copyAttributeValue(property, key);
            SEL accessor = sel_getUid(accessorName);
            if (sel_isEqual(selector, accessor))
            {
                propertyName = @(property_getName(property));
                break; // from for-loop
            }
            
            free(accessorName);
        }
        
        free(properties);
    }
    
    return propertyName;
}

static id getValueImplementation(NSObject *self, SEL _cmd) {
	return [self valueForUndefinedKey: propertyNameForAccessor([self class], _cmd)];
}

static void setValueImplementation(NSObject *self, SEL _cmd, id value) {
	[self setValue: value forUndefinedKey: propertyNameForAccessor([self class], _cmd)];
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
	NSString *propertyName = propertyNameForAccessor(self, sel);
	objc_property_t property = class_getProperty(self, propertyName.UTF8String);
	
	if (sel_isEqual(sel, getterForProperty(property))) {
		class_addMethod(self, sel, (IMP)getValueImplementation, "@@:");
	}
	
	char *readonly = property_copyAttributeValue(property, "R");
	if (!readonly && sel_isEqual(sel, setterForProperty(property))) {
		class_addMethod(self, sel, (IMP)setValueImplementation, "v@:@");
	}
	free(readonly);
	
	return [super resolveInstanceMethod: sel];
}

#pragma mark Private

- (void)sharedInit {
	self.baseQuery = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
					  (__bridge id)kSecAttrCreator: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"],
					  (__bridge id)kSecAttrAccount: self.identifier,
					  (__bridge id)kSecAttrService: self.serviceName};
}

#pragma mark Initializers

+ (id)storeForServiceName:(NSString *)name username:(NSString *)username contents:(id <NSCoding, NSObject>)contents userInfo:(NSDictionary *)userInfo {
	DZAuthenticationStore *ret = [[[self class] alloc] initWithServiceName: name];
	ret->_username = [username copy];
	ret->_userInfo = [userInfo copy];
	[ret setContents: contents];
	return ret;
}

+ (id)storeWithUsername:(NSString *)username contents:(id <NSCoding, NSObject>)contents userInfo:(NSDictionary *)userInfo {
	return [self storeForServiceName: nil username: username contents: contents userInfo: userInfo];
}

- (id)initWithServiceName:(NSString *)serviceName {
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	self = [self initWithServiceName: serviceName identifier:(__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid)];
	CFRelease(uuid);
	return self;
}

- (id)initWithServiceName:(NSString *)serviceName identifier:(NSString *)identifier {
    if ((self = [super init])) {
		self.serviceName = serviceName.length ? serviceName : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		self.identifier = identifier;

		[self sharedInit];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		NSMutableDictionary *authStore = [[defaults dictionaryForKey: DZAuthenticationStoreUserDefaultsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
		NSMutableArray *serviceStore = [authStore[serviceName] mutableCopy] ?: [NSMutableArray array];

		if (![serviceStore containsObject: self.identifier]) {
			[serviceStore addObject: self.identifier];
			authStore[serviceName] = serviceStore;
			[defaults setObject: authStore forKey: DZAuthenticationStoreUserDefaultsKey];
			[defaults synchronize];
		}
    }
    return self;
}

#pragma mark NS<Mutable>Copying

- (id)copyWithZone:(NSZone *)zone {
	DZAuthenticationStore *ret = [[[self class] alloc] initWithServiceName: self.serviceName identifier: self.identifier];
	ret->_username = [self.username copy];
	ret->_userInfo = [self.userInfo copy];
	return ret;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	DZMutableAuthenticationStore *new = [[DZMutableAuthenticationStore allocWithZone: zone] initWithServiceName: self.serviceName];
	new.username = self.username;
	new.userInfo = self.userInfo;
	new.contents = self.contents;
	return new;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
		_serviceName = [[aDecoder decodeObjectForKey: @"serviceName"] copy];
		_username = [[aDecoder decodeObjectForKey: @"username"] copy];
		_userInfo = [aDecoder decodeObjectForKey: @"userInfo"];
		_identifier = [aDecoder decodeObjectForKey: @"identifier"];
		[self sharedInit];
	}
	return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject: self.serviceName forKey: @"serviceName"];
	[aCoder encodeObject: self.username forKey: @"username"];
	[aCoder encodeObject: self.userInfo forKey: @"userInfo"];
	[aCoder encodeObject: self.identifier forKey: @"identifier"];
}

#pragma mark Properties

- (void) setUsername:(NSString *)username {
	if ([_username isEqual: username])
		return;
	
	_username = [username copy];
	
	if (!self.identifier)
		return;
	
	id contents = self.contents;
	
	if (!contents)
		return;
	
	[self setContents: contents];
}

- (void) setUserInfo:(NSDictionary *)userInfo {
	if ([_userInfo isEqualToDictionary: userInfo])
		return;
	
	_userInfo = [userInfo copy];
	
	if (!self.identifier)
		return;
	
	id contents = self.contents;
	
	if (!contents)
		return;
	
	[self setContents: contents];
}

- (void)setContents:(id<NSObject,NSCoding>)contents {
    CFMutableDictionaryRef query = (__bridge_retained CFMutableDictionaryRef)[self.baseQuery mutableCopy];
	
	NSMutableDictionary *userInfo = self.username.length ? [NSMutableDictionary dictionaryWithObject: self.username forKey: @"username"] : [NSMutableDictionary dictionary];
	[userInfo addEntriesFromDictionary:self.userInfo];
	NSData *userInfoData = [NSJSONSerialization dataWithJSONObject: userInfo options: 0 error: NULL];
	
    NSData *data = nil;
	
	if (contents) {
		if ([contents isKindOfClass:[NSString class]])
			data = [(NSString *)contents dataUsingEncoding: NSUTF8StringEncoding];
		else if ([NSJSONSerialization isValidJSONObject:contents])
			data = [NSJSONSerialization dataWithJSONObject: contents options: 0 error: NULL];
	}

    if (data.length) {
        id existingContents = self.contents;
        if (!existingContents) {
			CFDictionarySetValue(query, kSecAttrGeneric, (__bridge CFDataRef)userInfoData);
			CFDictionarySetValue(query, kSecValueData, (__bridge CFDataRef)data);
            OSStatus status = SecItemAdd(query, NULL);
            NSAssert(status == noErr, @"Error executing query on keychain.");
        } else {
			CFDictionaryRef updateQuery = (__bridge_retained CFDictionaryRef)@{ (__bridge id)kSecValueData : data, (__bridge id)kSecAttrGeneric : userInfoData };
            SecItemUpdate(query, updateQuery);
			CFRelease(updateQuery);
        }
    } else {
        SecItemDelete(query);
    }
	
	CFRelease(query);
}

- (id<NSCoding>)contents {
    CFMutableDictionaryRef query = (__bridge_retained CFMutableDictionaryRef)[self.baseQuery mutableCopy];
    CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching(query, &result);
	CFRelease(query);
    
    if (status != noErr)
        return nil;
    
    NSData *data = (__bridge_transfer NSData *)result;
    id ret = nil;
    if (!(ret = [NSJSONSerialization JSONObjectWithData: data options: 0 error: NULL])) {
		ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
    return ret;
}

- (void)evict {
	[self setContents: nil];
}

#pragma mark Basic KVC

- (id)valueForUndefinedKey:(NSString *)key {
	NSSet *userInfoKeys = [[self class] keyPathsForValuesAffectingValueForKey: @"userInfo"];
	NSSet *contentsKeys = [[self class] keyPathsForValuesAffectingValueForKey: @"contents"];
	
	if ([contentsKeys containsObject: key]) {
		if (contentsKeys.count > 1) {
			return ((NSDictionary *)self.contents)[key];
		} else {
			return self.contents;
		}
	} else if ([userInfoKeys containsObject: key]) {
		return (self.userInfo)[key];
	} else {
		return [super valueForUndefinedKey: key];
	}
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
	BOOL isMutable = ([NSStringFromClass([self class]) rangeOfString:@"Mutable"].location != NSNotFound);
	
	NSSet *userInfoKeys = [[self class] keyPathsForValuesAffectingValueForKey: @"userInfo"];
	NSSet *contentsKeys = [[self class] keyPathsForValuesAffectingValueForKey: @"contents"];
	
	if (isMutable && [contentsKeys containsObject: key]) {
		if (contentsKeys.count > 1) {
			NSMutableDictionary *userInfo = [(NSDictionary *)self.contents mutableCopy] ?: [NSMutableDictionary dictionary];
			userInfo[key] = value;
			self.contents = userInfo;
		} else {
			self.contents = value;
		}
	} else if (isMutable && [userInfoKeys containsObject: key]) {
		NSMutableDictionary *userInfo = [self.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
		userInfo[key] = value;
		self.userInfo = userInfo;
	} else {
		[super setValue: value forUndefinedKey: key];
	}
}

@end

@implementation DZMutableAuthenticationStore



@end

@implementation DZAuthenticationStore (DZAuthenticationStoreFactory)

+ (NSSet *)findStoresForService:(NSString *)serviceName {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary *authStore = [defaults dictionaryForKey: DZAuthenticationStoreUserDefaultsKey];
	if (!authStore.count)
		return nil;

	NSArray *serviceMatches = authStore[serviceName];
	NSMutableSet *results = [NSMutableSet setWithCapacity: serviceMatches.count];
	for (NSString *identifier in serviceMatches) {
		id result = [[self class] findStoreForServiceName: serviceName identifier: identifier];
		if (result)
			[results addObject: result];
	}
	return [results copy];
}

+ (instancetype)findStoreForServiceName:(NSString *)serviceName identifier:(NSString *)unique {
	if (!serviceName.length || !unique.length)
		return nil;
	
	NSString *bundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass,
								  serviceName, (__bridge id)kSecAttrService,
								  bundleIdentifier, (__bridge id)kSecAttrCreator,
								  unique, (__bridge id)kSecAttrAccount,
								  (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnAttributes,
								  (__bridge id)kSecMatchLimitOne, (__bridge id)kSecMatchLimit,
								  nil];
	CFDictionaryRef attributes = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&attributes);
    
    if (status != noErr)
        return nil;
	
	NSDictionary *match = (__bridge_transfer NSDictionary *)attributes;
	NSData *userInfoData = match[(__bridge id)kSecAttrGeneric];
	
	NSMutableDictionary *userInfo = [[NSJSONSerialization JSONObjectWithData: userInfoData options: 0 error: NULL] mutableCopy];
	NSString *username = userInfo[@"username"];
	[userInfo removeObjectForKey: @"username"];

	DZAuthenticationStore *ret = [[self alloc] initWithServiceName: serviceName identifier: unique];
	ret->_username = [username copy];
	ret->_userInfo = [userInfo copy];
	return ret;
}

+ (instancetype)findStoreForServiceName:(NSString *)serviceName username:(NSString *)username {
	if (!serviceName.length || !username.length)
		return nil;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary *authStore = [defaults dictionaryForKey: DZAuthenticationStoreUserDefaultsKey];
	if (!authStore.count)
		return nil;
	
	__block id ret = nil;
	
	[authStore[serviceName] enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger idx, BOOL *stop) {
		DZAuthenticationStore *store = [[self class] findStoreForServiceName: serviceName identifier: identifier];

		if ([store.username isEqualToString: username]) {
			*stop = YES;
			ret = store;
		}
	}];
	
	return ret;
}

@end