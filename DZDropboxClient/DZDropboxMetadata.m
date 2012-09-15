//
//  DZDropboxMetadata.m
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxMetadata.h"

@implementation DZDropboxMetadata {
	NSDictionary *_original;
}

- (NSDateFormatter*)dateFormatter {
	static dispatch_once_t onceToken;
	static NSDateFormatter *dateFormatter = nil;
	dispatch_once(&onceToken, ^{
		dateFormatter = [NSDateFormatter new];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
	});
	return dateFormatter;
}

- (id)initWithDictionary:(NSDictionary*)dict {
    if ((self = [super init])) {
        _thumbnailExists = [dict[@"thumb_exists"] boolValue];
        _totalBytes = [dict[@"bytes"] longLongValue];

        if (dict[@"modified"])
            _lastModifiedDate = [self.dateFormatter dateFromString: dict[@"modified"]];
		
		if (dict[@"client_mtime"])
            _clientMTime = [self.dateFormatter dateFromString: dict[@"client_mtime"]];

        _path = dict[@"path"];
		_filename = _path.lastPathComponent;
        _isDirectory = [dict[@"is_dir"] boolValue];

		NSArray *contentsDictionaries = dict[@"contents"];
        if (contentsDictionaries.count) {
			NSMutableArray *contents = [NSMutableArray arrayWithCapacity: contentsDictionaries.count];
			[contentsDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				[contents addObject: [[DZDropboxMetadata alloc] initWithDictionary:obj]];
			}];
			_contents = [contents copy];
		}
        
        _hash = dict[@"hash"];
        _humanReadableSize = dict[@"size"];
        _root = dict[@"root"];
        _icon = dict[@"icon"];
        _rev = dict[@"rev"];
        _revision = [dict[@"revision"] longLongValue];
        _isDeleted = [dict[@"is_deleted"] boolValue];
		
		_original = dict;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
	if (![object isKindOfClass:[DZDropboxMetadata class]])
		return NO;
	
    if (object == self)
		return YES;
	
    return [self.rev isEqualToString:[object rev]];
}

#pragma mark NSCoding methods

- (id)initWithCoder:(NSCoder *)coder {
	return [self initWithDictionary: [coder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject: _original];
}

@end
