/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import "TiModule.h"


typedef enum {
	READ_MODE = 1,
	WRITE_MODE = 2,
	READ_WRITE_MODE = 3 // Alias for READ | WRITE
} SocketMode;

@interface SocketModule : TiModule {
}

@property(readonly, nonatomic) NSNumber* READ_MODE;
@property(readonly, nonatomic) NSNumber* WRITE_MODE;
@property(readonly, nonatomic) NSNumber* READ_WRITE_MODE;

@end