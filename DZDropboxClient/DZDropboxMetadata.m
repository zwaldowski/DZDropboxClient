//
//  DZDropboxMetadata.m
//  Markable
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxMetadata.h"

@implementation DZDropboxMetadata {
	NSDictionary *_original;
}

+ (NSDateFormatter*)dateFormatter {
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
        _thumbnailExists = [[dict objectForKey:@"thumb_exists"] boolValue];
        _totalBytes = [[dict objectForKey:@"bytes"] longLongValue];

        if ([dict objectForKey:@"modified"])
            _lastModifiedDate = [[[self class] dateFormatter] dateFromString:[dict objectForKey:@"modified"]];
		
		if ([dict objectForKey:@"client_mtime"])
            _clientMTime = [[[self class] dateFormatter] dateFromString:[dict objectForKey:@"client_mtime"]];

        _path = [dict objectForKey:@"path"];
		_filename = [_path lastPathComponent];
        _isDirectory = [[dict objectForKey:@"is_dir"] boolValue];

		NSArray *contentsDictionaries = dict[@"contents"];
        if (contentsDictionaries.count) {
			NSMutableArray *contents = [NSMutableArray arrayWithCapacity: contentsDictionaries.count];
			[contentsDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				[contents addObject: [[DZDropboxMetadata alloc] initWithDictionary:obj]];
			}];
			_contents = [contents copy];
		}
        
        _hash = [dict objectForKey:@"hash"];
        _humanReadableSize = [dict objectForKey:@"size"];
        _root = [dict objectForKey:@"root"];
        _icon = [dict objectForKey:@"icon"];
        _rev = [dict objectForKey:@"rev"];
        _revision = [[dict objectForKey:@"revision"] longLongValue];
        _isDeleted = [[dict objectForKey:@"is_deleted"] boolValue];
		
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

- (id)initWithCoder:(NSCoder*)coder {
	return [self initWithDictionary:[coder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:_original];
}

@end
