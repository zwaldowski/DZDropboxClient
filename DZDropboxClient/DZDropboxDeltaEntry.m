//
//  DZDropboxDeltaEntry.h
//  DZDropboxClient
//
//  Created by Zachary Waldowski on 3/28/12.
//  Copyright (c) 2012 Dizzy Technology. All rights reserved.
//

#import "DZDropboxDeltaEntry.h"
#import "DZDropboxMetadata.h"

@implementation DZDropboxDeltaEntry

- (instancetype)initWithContents:(id)contents {
    if ((self = [super init])) {
		if ([contents isKindOfClass: [NSArray class]]) {
			NSArray *array = contents;
			_path = array[0];
			if (array.count > 1 && array[1] != [NSNull null])
				_metadata = [DZDropboxMetadata metadataWithDictionary: array[1]];
		} else {
			_path = contents;
		}
    }
    return self;
}

+ (instancetype)deltaEntryWithContents:(id)contents {
	return [[self alloc] initWithContents: contents];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super init])) {
		_path = [aDecoder decodeObjectForKey: @"path"];
		_metadata = [aDecoder decodeObjectForKey: @"metadata"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_metadata forKey:@"metadata"];
	[aCoder encodeObject:_path forKey:@"path"];
}

@end
