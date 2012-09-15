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

- (instancetype)initWithArray:(NSArray *)array {
    if ((self = [super init])) {
        _path = [array objectAtIndex:0];
        if ([array objectAtIndex:1] != [NSNull null])
            _metadata = [[DZDropboxMetadata alloc] initWithDictionary:[array objectAtIndex:1]];
    }
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super init])) {
		_path = [aDecoder decodeObjectForKey:@"path"];
		_metadata = [aDecoder decodeObjectForKey:@"metadata"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_metadata forKey:@"metadata"];
	[aCoder encodeObject:_path forKey:@"path"];
}

@end
