//
//  DZDropboxAccountInfo.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxAccountInfo.h"

@implementation DZDropboxAccountInfo {
	NSDictionary *_original;
}

- (id)initWithDictionary:(NSDictionary*)dict {
    if ((self = [super init])) {
        _country = dict[@"country"];
        _displayName = dict[@"display_name"];
		_quota = dict[@"quota_info"];
        _userID = [dict[@"uid"] stringValue];
        _referralLink = dict[@"referral_link"];
		_original = dict;
    }
    return self;
}

#pragma mark NSCoding methods

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:_original];
}

- (id)initWithCoder:(NSCoder*)coder {
	return [self initWithDictionary:[coder decodeObject]];
}

#pragma mark Quota methods

- (long long)normalConsumedBytes {
	return [(self.quota)[@"normal"] longLongValue];
}

- (long long)sharedConsumedBytes {
	return [(self.quota)[@"shared"] longLongValue];
}

- (long long)totalBytes {
	return [(self.quota)[@"quota"] longLongValue];
}

- (long long)totalConsumedBytes {
	return self.normalConsumedBytes + self.sharedConsumedBytes;
}

@end
