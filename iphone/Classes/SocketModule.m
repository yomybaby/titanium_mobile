/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "SocketModule.h"
#import "TiBase.h"
#import "TiSocketTCPProxy.h"

NSString* const INADDR_ANY_token = @"INADDR_ANY";

@implementation SocketModule

-(NSNumber*)READ_MODE
{
    return [NSNumber numberWithInt:READ_MODE];
}

-(NSNumber*)WRITE_MODE
{
    return [NSNumber numberWithInt:WRITE_MODE];
}

-(NSNumber*)READ_WRITE_MODE
{
    return [NSNumber numberWithInt:READ_WRITE_MODE];
}

-(NSString*)INADDR_ANY
{
    return INADDR_ANY_token;
}

@end