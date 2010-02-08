/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "SocketModule.h"
#import "TiBase.h"
#import "TiTCPSocketProxy.h"

@implementation SocketModule

const NSString* hostArg = @"host";
const NSString* portArg = @"port";
const NSString* modeArg = @"mode";

-(id)createTCPSocket:(id)args
{
    // Args are an NSArray of one NSDict; or better be.
    ENSURE_ARRAY(args)
    ENSURE_DICT([args objectAtIndex:0])
    
    NSDictionary* argsDict = [args objectAtIndex:0];
    
    int port = 0;
    SocketMode mode = READ_MODE;
    
    ENSURE_TYPE([argsDict objectForKey:hostArg], NSString)
    NSString* hostName = [argsDict objectForKey:hostArg];
    
    ENSURE_TYPE([argsDict objectForKey:portArg], NSNumber)
    port = [[argsDict objectForKey:portArg] intValue];
    
    // TODO: Even check for NSNull here?
    if ([argsDict objectForKey:modeArg] && ![[argsDict objectForKey:modeArg] isKindOfClass:[NSNull class]]) {
        ENSURE_TYPE([argsDict objectForKey:modeArg], NSNumber)
        mode = [[argsDict objectForKey:modeArg] intValue];
        
        // I was unable to find good information on how Obj-C (or C) handles out-of-range enumeration,
        // so we check here.
        switch (mode) {
            case READ_MODE:
            case WRITE_MODE:
            case READ_WRITE_MODE:
                break;
            default:
                [self throwException:TiExceptionRangeError
                           subreason:[NSString stringWithFormat:@"bad value for mode: %d", mode]
                            location:CODELOCATION];
        }
    }
    
    TiTCPSocketProxy* socket = [[[TiTCPSocketProxy alloc] initWithContext:[self pageContext] host:hostName port:port mode:mode] autorelease];
    
    return socket;
}

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

@end